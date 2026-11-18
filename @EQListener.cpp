#include "Resources/@EQListener.h"

// @EQListener: WASAPI back-end for @EQ, from corz.org
// https://corz.org/windows/software/@EQ/
//
// Captures the VB-Audio HiFi CABLE output, runs the preset EQ convolution,
// renders to the real speaker output linked to the current monitor.
// Watches WM_DISPLAYCHANGE, WM_DEVICECHANGE and
// IMMNotificationClient.OnDefaultDeviceChanged, then reloads the
// preset from %AppData%\corz\@EQ\@EQ.ini with a 200 ms crossfade.
//
// Requires VB CABLE: https://vb-audio.com/Cable/
//
#include <windows.h>
#include <shlobj.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <endpointvolume.h>
#include <functiondiscoverykeys_devpkey.h>
#include <ksmedia.h>
#include <stdio.h>
#include <io.h>
#include <share.h>
#include <string>
#include <vector>
#include <cmath>
#include <complex>
#include <algorithm>
#include <memory>
#include <future>
#include <chrono>
#include <climits>

#define XFADE_SEC 0.2
#define MAX_BANDS 32

static const double GAIN_MIN_DB = -24.0, GAIN_MAX_DB = 24.0;
static const DWORD MASTER_VOLUME_POLL_MS = 30;
static const DWORD CAPTURE_RETRY_MS = 2000;

// Keep silent CABLE playback separate from the audible output session.
static const GUID CABLE_SILENCE_SESSION_GUID = {
  0x32f8f61b, 0xe082, 0x4f0e, {0x9e, 0x6b, 0xc4, 0xab, 0x15, 0xa7, 0xb3, 0x20}
};
static const double PI_D = 3.14159265358979323846;

struct Band {
  double freq = 1000.0;
  double gain_db = 0.0;
};

// A 1024-frame partition adds 21.33 ms at 48 kHz. The full FIR is
// minimum phase; its length does not add a half-impulse linear-phase delay.
static const size_t GRAPHIC_BLOCK = 1024;
static const size_t GRAPHIC_FFT = GRAPHIC_BLOCK * 2;
static const double GRAPHIC_RESOLUTION_HZ = 0.25;
using Spectrum = std::vector<std::complex<double>>;

// Transform a power-of-two spectrum in place; inverse includes 1/N scaling.
// Called during response design and once per convolution block/channel.
static void GraphicFFT(Spectrum &data, bool inverse) {
  const size_t n = data.size();
  for (size_t i = 1, j = 0; i < n; ++i) {
    size_t bit = n >> 1;
    for (; j & bit; bit >>= 1) j ^= bit;
    j ^= bit;
    if (i < j) std::swap(data[i], data[j]);
  }
  for (size_t length = 2; length <= n; length <<= 1) {
    const auto step = std::polar(1.0, (inverse ? 2 : -2) * PI_D / length);
    for (size_t offset = 0; offset < n; offset += length) {
      std::complex<double> phase = 1;
      for (size_t j = 0; j < length / 2; ++j) {
        auto even = data[offset + j], odd = data[offset + j + length / 2] * phase;
        data[offset + j] = even + odd;
        data[offset + j + length / 2] = even - odd;
        phase *= step;
      }
    }
  }
  if (inverse) for (auto &value : data) value /= double(n);
}

// Evaluate the GraphicEQ target in dB from sorted unique positive-Hz points.
// Frequencies outside the points use the nearest endpoint; no points is 0 dB.
static double GraphicGain(const std::vector<Band> &points, double frequency) {
  if (points.empty()) return 0;
  if (frequency <= points.front().freq) return points.front().gain_db;
  for (size_t i = 1; i < points.size(); ++i) {
    if (frequency <= points[i].freq) {
      const Band &a = points[i - 1], &b = points[i];
      return a.gain_db + (b.gain_db - a.gain_db) * log(frequency / a.freq) / log(b.freq / a.freq);
    }
  }
  return points.back().gain_db;
}

static const int MAX_AUDIO_CHANNELS = 8;
static const size_t AUDIO_QUEUE_SECONDS = 2;
// Smooth packet scheduling jitter before correcting independent device clocks.
static const double CAPTURE_DRIFT_FILTER_SECONDS = 2.0;
static const double CAPTURE_DRIFT_SETTLE_SECONDS = 10.0;
static const double CAPTURE_DRIFT_MAX_RATIO = 0.002;

// Bounds capture memory while preserving interleaved channel order on overflow.
// Reset receives sample capacity and channels per frame; PushFrame appends one
// complete frame and discards the oldest complete frame when full. Drop rounds
// sample counts down to complete frames. Indexed reads address queued samples.
// Only the audio thread accesses this queue; PushFrame never reallocates.
class AudioQueue {
  std::vector<float> samples;
  size_t first = 0, count = 0, frame_samples = 0;
public:
  void Reset(size_t capacity, size_t channels) {
    frame_samples = channels;
    samples.assign(channels ? capacity - capacity % channels : 0, 0);
    clear();
  }
  void clear() { first = count = 0; }
  size_t size() const { return count; }
  float operator[](size_t index) const {
    size_t offset = first + index;
    return samples[offset < samples.size() ? offset : offset - samples.size()];
  }
  void Drop(size_t amount) {
    if (samples.empty()) return;
    amount = (std::min)(amount, count);
    amount -= amount % frame_samples;
    first += amount;
    if (first >= samples.size()) first -= samples.size();
    count -= amount;
  }
  // Appends the supplied interleaved frame, retaining whole frames on overflow.
  // Reads exactly Reset's channel count; an empty queue allocation discards it.
  void PushFrame(const float *frame) {
    if (samples.empty()) return;
    if (count == samples.size()) Drop(frame_samples);
    for (size_t channel = 0; channel < frame_samples; ++channel) {
      size_t offset = first + count;
      if (offset >= samples.size()) offset -= samples.size();
      samples[offset] = frame[channel];
      ++count;
    }
  }
};

// Resamples consecutive capture packets without treating packet edges as gaps.
// Reset receives capture channels; Append reads interleaved float frames and
// preserves the previous packet's last frame, including silence transitions.
// Step adjusts the nominal rate toward a caller-supplied queue reserve so
// independent capture/render clocks do not accumulate seconds of latency.
// The audio thread owns this state; reset it when the output or queue resets.
class CaptureResampler {
  std::vector<float> previous;
  double position = 0, queue_average = 0;
  bool queue_ready = false;

public:
  // Discards packet history and clock correction for the capture channel count.
  // Returns no value; the next packet begins at its own first frame.
  void Reset(size_t capture_channels) {
    previous.assign(capture_channels, 0.0f);
    position = queue_average = 0;
    queue_ready = false;
  }

  // Returns source frames per output frame, corrected by at most 0.2 percent.
  // Takes both rates in Hz, packet length in capture frames and queue/reserve
  // lengths in output frames. Two-second filtering suppresses packet jitter;
  // positive queue error increases consumption. Reads no devices or settings.
  double Step(double capture_rate, double output_rate, size_t packet_frames, size_t queued_frames, size_t reserve_frames) {
    if (!queue_ready) { queue_average = double(reserve_frames); queue_ready = true; }
    double seconds = double(packet_frames) / capture_rate;
    double blend = -std::expm1(-seconds / CAPTURE_DRIFT_FILTER_SECONDS);
    queue_average += blend * (double(queued_frames) - queue_average);
    double correction = (queue_average - double(reserve_frames)) / (output_rate * CAPTURE_DRIFT_SETTLE_SECONDS);
    correction = (std::max)(-CAPTURE_DRIFT_MAX_RATIO, (std::min)(CAPTURE_DRIFT_MAX_RATIO, correction));
    return capture_rate / output_rate * (1.0 + correction);
  }

  // Appends linearly interpolated complete output frames at the supplied step.
  // Reads the packet or zeros when silent/null; duplicates the final capture
  // channel into additional output channels. Defers interpolation requiring
  // the next packet, adding at most one capture frame of lookahead. A silent
  // packet retains the previous audible tail. Empty/invalid inputs do nothing.
  void Append(const float *samples, size_t frames, bool silent, size_t output_channels, double step, AudioQueue &queue) {
    if (!frames || previous.empty() || !output_channels || output_channels > MAX_AUDIO_CHANNELS || !(step > 0) || !std::isfinite(step)) return;
    silent = silent || !samples;
    size_t capture_channels = previous.size();
    while (position < double(frames) - 1.0) {
      int from_index = int(std::floor(position));
      double fraction = position - from_index;
      float frame[MAX_AUDIO_CHANNELS];
      for (size_t channel = 0; channel < output_channels; ++channel) {
        size_t source = channel < capture_channels ? channel : capture_channels - 1;
        double from = from_index < 0 ? previous[source] : (silent ? 0.0 : samples[size_t(from_index) * capture_channels + source]);
        double to = silent ? 0.0 : samples[size_t(from_index + 1) * capture_channels + source];
        frame[channel] = float(from + (to - from) * fraction);
      }
      queue.PushFrame(frame);
      position += step;
    }
    position -= double(frames);
    for (size_t channel = 0; channel < capture_channels; ++channel)
      previous[channel] = silent ? 0.0f : samples[(frames - 1) * capture_channels + channel];
  }
};

// Choose the same power-of-two FIR design length for kernels and input history.
// Receives render Hz; returns at least GRAPHIC_FFT with the target resolution.
static size_t GraphicDesignSize(double fs) {
  size_t design_size = GRAPHIC_FFT;
  while (double(design_size) < fs / GRAPHIC_RESOLUTION_HZ) design_size *= 2;
  return design_size;
}

struct GraphicInputChannel {
  std::vector<Spectrum> history;
  std::vector<double> previous = std::vector<double>(GRAPHIC_BLOCK);
  std::vector<double> current = std::vector<double>(GRAPHIC_BLOCK);
};

// One input history serves both filters throughout a preset transition.
struct GraphicInput {
  std::vector<GraphicInputChannel> state;
  size_t position = 0, head = 0, count = 0;
  GraphicInput() = default;
  GraphicInput(double fs, int channels) : state(channels), count(GraphicDesignSize(fs) / 2 / GRAPHIC_BLOCK) {
    for (auto &channel : state) channel.history.assign(count, Spectrum(GRAPHIC_FFT));
  }
};

struct GraphicChannel {
  Spectrum sum = Spectrum(GRAPHIC_FFT);
  std::vector<double> output = std::vector<double>(GRAPHIC_BLOCK);
};

struct Bank {
  std::vector<Spectrum> kernels;
  std::vector<GraphicChannel> state;
  double preamp_lin = 1, constant_gain = 1;
  bool ready = false, constant = false;
};

// Return one delayed, preamplified frame, clipped to [-1, 1]. Reads the bank's
// queued output at the shared input position; modifies frame, not input history.
// Called for one bank normally and both banks during the 200 ms crossfade.
static void RunBank(const Bank &bank, float *frame, int channels, size_t position) {
  for (int ch = 0; ch < channels; ++ch) {
    double sample = bank.state[ch].output[position] * bank.preamp_lin;
    frame[ch] = float((std::max)(-1.0, (std::min)(1.0, sample)));
  }
}

// Transform each completed input block once, independent of the filter count.
// Receives a full current block; writes overlap-save spectra for previous plus
// current input, swaps raw blocks, and advances head to the next history slot.
// Called only after all GRAPHIC_BLOCK output frames have been consumed.
static void CompleteGraphicBlock(GraphicInput &input) {
  for (auto &channel : input.state) {
    auto &spectrum = channel.history[input.head];
    for (size_t i = 0; i < GRAPHIC_BLOCK; ++i) {
      spectrum[i] = channel.previous[i];
      spectrum[i + GRAPHIC_BLOCK] = channel.current[i];
    }
    GraphicFFT(spectrum, false);
    channel.previous.swap(channel.current);
  }
  input.head = (input.head + 1) % input.count;
  input.position = 0;
}

// Queue a filter's output for the last completed input block, without copying
// history. Reads kernels and shared input; writes per-channel output and sum.
// Overlap-save discards the first FFT half, so replacement filters need one
// convolution per channel and no reconstruction of an earlier overlap block.
// Constant curves use raw delayed input instead of convolution. No allocation.
static void CalculateBankBlock(Bank &bank, const GraphicInput &input) {
  for (size_t ch = 0; ch < bank.state.size(); ++ch) {
    auto &state = bank.state[ch];
    const auto &channel = input.state[ch];
    if (bank.constant) {
      for (size_t i = 0; i < GRAPHIC_BLOCK; ++i) state.output[i] = channel.previous[i] * bank.constant_gain;
      continue;
    }
    std::fill(state.sum.begin(), state.sum.end(), 0);
    for (size_t part = 0; part < bank.kernels.size(); ++part) {
      const auto &spectrum = channel.history[(input.head + input.count - 1 - part) % input.count];
      for (size_t i = 0; i < GRAPHIC_FFT; ++i) state.sum[i] += spectrum[i] * bank.kernels[part][i];
    }
    GraphicFFT(state.sum, true);
    for (size_t i = 0; i < GRAPHIC_BLOCK; ++i) state.output[i] = state.sum[i + GRAPHIC_BLOCK].real();
  }
}

// Make the cable's Windows master fader control the linked physical output.
// Owns the supplied endpoint interfaces. On output changes, copies the physical
// volume/mute to the cable so startup cannot raise the speaker volume. Sync
// forwards cable changes to speakers and physical changes back to the cable.
// Does not scale audio samples, change preset preamp or write settings.
class MasterVolumeBridge {
  IAudioEndpointVolume *control = nullptr, *output = nullptr;
  float last_control = 0, last_output = 0;
  BOOL last_control_mute = FALSE, last_output_mute = FALSE;
  bool ready = false;

  static bool Read(IAudioEndpointVolume *endpoint, float &gain, BOOL &mute) {
    return endpoint && SUCCEEDED(endpoint->GetMasterVolumeLevelScalar(&gain)) && SUCCEEDED(endpoint->GetMute(&mute));
  }

public:
  ~MasterVolumeBridge() {
    if (control) control->Release();
    if (output) output->Release();
  }
  void SetControl(IAudioEndpointVolume *endpoint) {
    if (control) control->Release();
    control = endpoint;
    ready = false;
    if (output) { output->AddRef(); SetOutput(output); }
  }
  void SetOutput(IAudioEndpointVolume *endpoint) {
    if (output) output->Release();
    output = endpoint;
    ready = false;
    if (!Read(output, last_output, last_output_mute) || !control) return;
    if (FAILED(control->SetMasterVolumeLevelScalar(last_output, nullptr)) || FAILED(control->SetMute(last_output_mute, nullptr))) return;
    ready = Read(control, last_control, last_control_mute);
  }
  void Sync() {
    if (!ready) return;
    float control_gain = 0, output_gain = 0;
    BOOL control_mute = FALSE, output_mute = FALSE;
    if (!Read(control, control_gain, control_mute) || !Read(output, output_gain, output_mute)) return;
    if (control_gain != last_control || control_mute != last_control_mute) {
      if (control_gain != last_control && FAILED(output->SetMasterVolumeLevelScalar(control_gain, nullptr))) return;
      if (control_mute != last_control_mute && FAILED(output->SetMute(control_mute, nullptr))) return;
      if (!Read(output, output_gain, output_mute)) return;
    }
    bool control_written = output_gain != control_gain || output_mute != control_mute;
    if (output_gain != control_gain && FAILED(control->SetMasterVolumeLevelScalar(output_gain, nullptr))) return;
    if (output_mute != control_mute && FAILED(control->SetMute(output_mute, nullptr))) return;
    if (control_written && !Read(control, control_gain, control_mute)) return;
    last_control = control_gain;
    last_control_mute = control_mute;
    last_output = output_gain;
    last_output_mute = output_mute;
  }
};

static std::string IniPath() {
  char appdata[MAX_PATH] = {0};
  if (!SUCCEEDED(SHGetFolderPathA(NULL, CSIDL_APPDATA, NULL, 0, appdata))) return "";
  return std::string(appdata) + "\\corz\\@EQ\\@EQ.ini";
}

static std::string IniStr(const std::string &ini, const char *sec, const char *key, const char *dflt) {
  char buf[1024] = {0};
  GetPrivateProfileStringA(sec, key, dflt, buf, sizeof(buf), ini.c_str());
  return std::string(buf);
}

// Loads a preset section into bands plus preamp gain in dB.
// Receives an exact preset/monitor/mode section; false when Mode is absent.
static bool LoadPreset(const std::string &ini, const std::string &preset,
    std::vector<Band> &bands, double &preamp_db) {
  std::string sec = preset;
  std::string mode = IniStr(ini, sec.c_str(), "Mode", "");
  if (mode.empty()) return false;
  int n = GetPrivateProfileIntA(sec.c_str(), "BandCount", 10, ini.c_str());
  if (n < 1) n = 1;
  if (n > MAX_BANDS) n = MAX_BANDS;
  char tmp[32];
  sprintf_s(tmp, "0");
  char pdb[32] = {0};
  GetPrivateProfileStringA(sec.c_str(), "Preamp", "0", pdb, sizeof(pdb), ini.c_str());
  preamp_db = std::clamp(atof(pdb), GAIN_MIN_DB, GAIN_MAX_DB);
  bands.clear();
  for (int i = 0; i < n; i++) {
    Band b;
    char kf[32], kg[32];
    sprintf_s(kf, "Band%d_Freq", i);
    sprintf_s(kg, "Band%d_Gain", i);
    char vf[32] = {0}, vg[32] = {0};
    GetPrivateProfileStringA(sec.c_str(), kf, "1000", vf, sizeof(vf), ini.c_str());
    GetPrivateProfileStringA(sec.c_str(), kg, "0", vg, sizeof(vg), ini.c_str());
    b.freq = atof(vf); b.gain_db = std::clamp(atof(vg), GAIN_MIN_DB, GAIN_MAX_DB);
    bands.push_back(b);
  }
  return true;
}

// Design one minimum-phase FIR from the entire dB/log-Hz target curve.
// Reads frequency/gain points, preamp dB, render Hz and channel count. Invalid
// points are skipped; the last duplicate frequency wins. Clears queued output.
// Constant curves use delayed gain; other curves produce partitioned kernels.
// Shared input history is independent of the bank and is not allocated here.
// Real-cepstrum spectral factorisation gives the target magnitude without
// stacking bell filters. Called on preset reload and render-device changes.
static void BuildBank(Bank &bank, const std::vector<Band> &bands, double preamp_db, double fs, int channels) {
  std::vector<Band> points;
  for (const auto &band : bands)
    if (std::isfinite(band.freq) && band.freq > 0 && std::isfinite(band.gain_db)) points.push_back(band);
  std::stable_sort(points.begin(), points.end(), [](const Band &a, const Band &b) { return a.freq < b.freq; });
  std::vector<Band> unique;
  for (const auto &point : points) {
    if (!unique.empty() && unique.back().freq == point.freq) unique.back() = point;
    else unique.push_back(point);
  }
  const size_t design_size = GraphicDesignSize(fs);
  const size_t tap_count = design_size / 2;
  bank = Bank();
  bank.ready = true;
  bank.preamp_lin = pow(10.0, preamp_db / 20.0);
  bank.state.resize(channels);
  bank.constant = unique.empty() || std::all_of(unique.begin(), unique.end(), [&](const Band &point) { return point.gain_db == unique.front().gain_db; });
  if (bank.constant) {
    bank.constant_gain = unique.empty() ? 1.0 : pow(10.0, unique.front().gain_db / 20.0);
    return;
  }
  Spectrum impulse(design_size);
  for (size_t i = 0; i <= design_size / 2; ++i) {
    impulse[i] = GraphicGain(unique, double(i) * fs / design_size) * log(10.0) / 20.0;
    if (i && i < design_size / 2) impulse[design_size - i] = impulse[i];
  }
  GraphicFFT(impulse, true);
  for (size_t i = 1; i < design_size / 2; ++i) impulse[i] *= 2.0;
  for (size_t i = design_size / 2 + 1; i < design_size; ++i) impulse[i] = 0;
  GraphicFFT(impulse, false);
  for (auto &value : impulse) value = std::exp(value);
  GraphicFFT(impulse, true);
  // Taper only the late tail to suppress truncation ripple at sharp corners.
  for (size_t i = tap_count / 2; i < tap_count; ++i)
    impulse[i] *= 0.5 + 0.5 * cos(PI_D * double(i - tap_count / 2) / double(tap_count / 2 - 1));
  bank.kernels.assign(tap_count / GRAPHIC_BLOCK, Spectrum(GRAPHIC_FFT));
  for (size_t part = 0; part < bank.kernels.size(); ++part) {
    for (size_t i = 0; i < GRAPHIC_BLOCK; ++i) bank.kernels[part][i] = impulse[part * GRAPHIC_BLOCK + i].real();
    GraphicFFT(bank.kernels[part], false);
  }
}

// Resolves the active physical monitor on Windows' primary desktop adapter.
// Ignores disconnected monitor records, including stale entries enumerated
// before the active monitor. Returns an empty string if none is active.
static std::string CurrentMonitor() {
  DISPLAY_DEVICEA adapter;
  ZeroMemory(&adapter, sizeof(adapter));
  adapter.cb = sizeof(adapter);
  for (DWORD i = 0; EnumDisplayDevicesA(NULL, i, &adapter, 0); i++) {
    if (!(adapter.StateFlags & DISPLAY_DEVICE_PRIMARY_DEVICE)) continue;
    DISPLAY_DEVICEA screen;
    ZeroMemory(&screen, sizeof(screen));
    screen.cb = sizeof(screen);
    for (DWORD j = 0; EnumDisplayDevicesA(adapter.DeviceName, j, &screen, 0); j++) {
      if (screen.StateFlags & DISPLAY_DEVICE_ACTIVE) return screen.DeviceID;
    }
  }
  return "";
}

static std::string WideToUtf8(const WCHAR *w) {
  char buf[1024] = {0};
  WideCharToMultiByte(CP_UTF8, 0, w, -1, buf, sizeof(buf) - 1, NULL, NULL);
  return std::string(buf);
}

static std::string EndpointName(IMMDevice *dev) {
  IPropertyStore *ps = NULL;
  if (FAILED(dev->OpenPropertyStore(STGM_READ, &ps))) return "";
  PROPVARIANT v; PropVariantInit(&v);
  std::string out;
  if (SUCCEEDED(ps->GetValue(PKEY_Device_FriendlyName, &v)) && v.vt == VT_LPWSTR && v.pwszVal)
    out = WideToUtf8(v.pwszVal);
  PropVariantClear(&v);
  ps->Release();
  return out;
}

// True when a mix format carries 32 bit float samples, plain
// or extensible. Anything else exits with a message instead
// of misreading the buffers.
static bool IsFloatFormat(const WAVEFORMATEX *f) {
  if (!f) return false;
  if (f->wFormatTag == WAVE_FORMAT_IEEE_FLOAT) return true;
  if (f->wFormatTag == WAVE_FORMAT_EXTENSIBLE && f->cbSize >= 22) {
    const WAVEFORMATEXTENSIBLE *x = (const WAVEFORMATEXTENSIBLE *)f;
    return IsEqualGUID(x->SubFormat, KSDATAFORMAT_SUBTYPE_IEEE_FLOAT) && x->Samples.wValidBitsPerSample == 32;
  }
  return false;
}

// Finds an endpoint of the given flow whose name contains
// match (case sensitive substring). CABLE Output is a capture
// endpoint, so capture lookups must pass eCapture.
// Returns the id string, else "".
static std::string FindEndpoint(IMMDeviceEnumerator *en, EDataFlow flow, const char *match) {
  IMMDeviceCollection *col = NULL;
  if (FAILED(en->EnumAudioEndpoints(flow, DEVICE_STATE_ACTIVE, &col))) return "";
  UINT n = 0; col->GetCount(&n);
  std::string hit;
  for (UINT i = 0; i < n; i++) {
    IMMDevice *dev = NULL;
    if (FAILED(col->Item(i, &dev))) continue;
    std::string name = EndpointName(dev);
    LPWSTR idw = NULL;
    if (SUCCEEDED(dev->GetId(&idw))) {
      std::string id = WideToUtf8(idw);
      CoTaskMemFree(idw);
      if (name.find(match) != std::string::npos && hit.empty()) hit = id;
    }
    dev->Release();
  }
  col->Release();
  return hit;
}

// Prints either endpoint records or the default output ID for CLI queries.
static int CmdList(bool default_only = false) {
  CoInitialize(NULL);
  IMMDeviceEnumerator *en = NULL;
  if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL,
      __uuidof(IMMDeviceEnumerator), (void **)&en))) return 1;
  if (!default_only) {
    IMMDeviceCollection *col = NULL;
    if (FAILED(en->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE | DEVICE_STATE_UNPLUGGED, &col))) { en->Release(); return 1; }
    UINT n = 0; col->GetCount(&n);
    for (UINT i = 0; i < n; i++) {
      IMMDevice *dev = NULL;
      if (FAILED(col->Item(i, &dev))) continue;
      LPWSTR idw = NULL;
      if (SUCCEEDED(dev->GetId(&idw))) {
        printf("%s|%s\n", WideToUtf8(idw).c_str(), EndpointName(dev).c_str());
        CoTaskMemFree(idw);
      }
      dev->Release();
    }
    col->Release();
  }
  if (default_only) {
    IMMDevice *default_device = nullptr;
    if (SUCCEEDED(en->GetDefaultAudioEndpoint(eRender, eMultimedia, &default_device))) {
      LPWSTR default_id = nullptr;
      if (SUCCEEDED(default_device->GetId(&default_id))) {
        printf("DefaultOutput=%s\n", WideToUtf8(default_id).c_str());
        CoTaskMemFree(default_id);
      }
      default_device->Release();
    }
  }
  en->Release();
  return 0;
}

// Device change notifier: any default change sets the reload
// event so the main loop re-reads monitor, binding, endpoint.
class Notifier : public IMMNotificationClient {
  LONG refs = 1;
  HANDLE ev;
public:
  Notifier(HANDLE e) : ev(e) {}
  STDMETHODIMP QueryInterface(REFIID id, void **o) {
    if (id == __uuidof(IMMNotificationClient) || id == __uuidof(IUnknown)) { *o = this; AddRef(); return S_OK; }
    *o = NULL; return E_NOINTERFACE;
  }
  STDMETHODIMP_(ULONG) AddRef() { return InterlockedIncrement(&refs); }
  STDMETHODIMP_(ULONG) Release() {
    ULONG r = (ULONG)InterlockedDecrement(&refs);
    if (!r) delete this;
    return r;
  }
  STDMETHODIMP OnDeviceStateChanged(LPCWSTR, DWORD) { SetEvent(ev); return S_OK; }
  STDMETHODIMP OnDeviceAdded(LPCWSTR) { SetEvent(ev); return S_OK; }
  STDMETHODIMP OnDeviceRemoved(LPCWSTR) { SetEvent(ev); return S_OK; }
  STDMETHODIMP OnDefaultDeviceChanged(EDataFlow, ERole, LPCWSTR) { SetEvent(ev); return S_OK; }
  STDMETHODIMP OnPropertyValueChanged(LPCWSTR, const PROPERTYKEY) { return S_OK; }
};

static LRESULT CALLBACK HiddenWndProc(HWND h, UINT m, WPARAM w, LPARAM l) {
  if (m == WM_DESTROY) { PostQuitMessage(0); return 0; }
  if (m == WM_DISPLAYCHANGE || m == WM_DEVICECHANGE) {
    HANDLE ev = (HANDLE)GetWindowLongPtrA(h, GWLP_USERDATA);
    if (ev) SetEvent(ev);
    return 0;
  }
  return DefWindowProcA(h, m, w, l);
}

// Prevents idle CABLE playback from damaging short sounds on stream startup.
// In other words, without this, system beeps and such will crackle and distort.
// Opens a shared stream on the supplied CABLE Input endpoint and mixes only
// zero-valued samples. The existing listener loop fills its native buffers;
// no channels are reserved and no additional audio thread is created.
// Its dedicated session is hidden from the mixer and expires on release.
class CableSilenceStream {
  IAudioClient *client = nullptr;
  IAudioRenderClient *render = nullptr;
  HANDLE event = nullptr;
  UINT32 capacity = 0;
  WORD frame_bytes = 0;

public:
  // Releases this stream's resources when the listener leaves main().
  ~CableSilenceStream() { Close(); }

  // Returns the packet-ready event, or nullptr when no stream is open.
  HANDLE Event() const { return event; }

  // Stops this stream and releases its interfaces and event; returns no value.
  void Close() {
    if (client) client->Stop();
    if (render) { render->Release(); render = nullptr; }
    if (client) { client->Release(); client = nullptr; }
    if (event) { CloseHandle(event); event = nullptr; }
    capacity = 0;
    frame_bytes = 0;
  }

  // Fills available playback frames with zeros, retaining other shared audio.
  // Returns true for a filled/full buffer, false for an unavailable stream or
  // failed WASAPI call. The listener closes and retries failed streams.
  bool Fill() {
    if (!client || !render) return false;
    UINT32 padding = 0;
    if (FAILED(client->GetCurrentPadding(&padding)) || padding > capacity) return false;
    UINT32 frames = capacity - padding;
    if (!frames) return true;
    BYTE *samples = nullptr;
    if (FAILED(render->GetBuffer(frames, &samples))) return false;
    memset(samples, 0, size_t(frames) * frame_bytes);
    return SUCCEEDED(render->ReleaseBuffer(frames, 0));
  }

  // Starts zero-sample playback on the supplied endpoint using its mix format.
  // Reads the enumerator and endpoint ID; returns true after Start succeeds,
  // false after releasing all partial resources on failure. No settings change.
  bool Open(IMMDeviceEnumerator *enumerator, const std::string &endpoint_id) {
    Close();
    if (endpoint_id.empty()) return false;
    WCHAR wide_id[512] = {};
    if (!MultiByteToWideChar(CP_UTF8, 0, endpoint_id.c_str(), -1, wide_id, 512)) return false;
    IMMDevice *device = nullptr;
    if (FAILED(enumerator->GetDevice(wide_id, &device))) return false;
    HRESULT result = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr, (void **)&client);
    device->Release();
    if (FAILED(result)) { Close(); return false; }
    WAVEFORMATEX *format = nullptr;
    result = client->GetMixFormat(&format);
    if (FAILED(result)) { Close(); return false; }
    frame_bytes = format->nBlockAlign;
    bool zero_is_silence = IsFloatFormat(format) || format->wBitsPerSample > CHAR_BIT;
    if (zero_is_silence && frame_bytes) {
      event = CreateEventA(nullptr, FALSE, FALSE, nullptr);
      result = event ? client->Initialize(AUDCLNT_SHAREMODE_SHARED,
        AUDCLNT_STREAMFLAGS_EVENTCALLBACK | AUDCLNT_SESSIONFLAGS_DISPLAY_HIDE | AUDCLNT_SESSIONFLAGS_EXPIREWHENUNOWNED,
        0, 0, format, &CABLE_SILENCE_SESSION_GUID) : E_FAIL;
    } else result = AUDCLNT_E_UNSUPPORTED_FORMAT;
    CoTaskMemFree(format);
    if (FAILED(result) || FAILED(client->SetEventHandle(event)) ||
        FAILED(client->GetService(__uuidof(IAudioRenderClient), (void **)&render)) ||
        FAILED(client->GetBufferSize(&capacity)) || !capacity || !Fill() || FAILED(client->Start())) {
      Close();
      return false;
    }
    return true;
  }
};

int main(int argc, char **argv) {
  if (argc > 1 && strcmp(argv[1], "--default") == 0) return argc == 2 ? CmdList(true) : 1;
  if (argc > 1 && strcmp(argv[1], "--list") == 0) return argc == 2 ? CmdList() : 1;
  if (argc > 1 && strcmp(argv[1], "--monitor") == 0) {
    printf("%s\n", CurrentMonitor().c_str());
    return 0;
  }
  if (argc > 1 && (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0)) {
    printf("@EQListener %s\n\n--list         list render endpoints (audio outputs) as id|name\n--default      print DefaultOutput=id\n--monitor      print current monitor id\n--ini <path>   use another ini file\n\nlogs to @EQListener.log next to @EQ.ini\n",
      VERSION_STR);
    return 0;
  }
  std::string ini_override;
  for (int i = 1; i + 1 < argc; i++) if (strcmp(argv[i], "--ini") == 0) ini_override = argv[i + 1];
  std::string ini = ini_override.empty() ? IniPath() : ini_override;
  if (ini.empty()) { printf("[@EQ] no appdata path\n"); return 1; }
  // Daemon mode: log to file. The binary links as a Windows
  // app so no console window ever appears; --list/--monitor
  // above still print when a console or pipe exists.
  size_t slash = ini.find_last_of("\\/");
  std::string log_file = (slash == std::string::npos ? "." : ini.substr(0, slash)) + "\\@EQListener.log";
  SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);
  HANDLE listener_mutex = CreateMutexA(NULL, TRUE, "@EQListenerSingleInstance");
  if (!listener_mutex) {
    OutputDebugStringA("[@EQ] cannot create single-instance mutex\n");
    return 1;
  }
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    const char *listener_duplicate_message = "[@EQ] another listener is already running, exiting\n";
    printf("%s", listener_duplicate_message);
    OutputDebugStringA(listener_duplicate_message);
    CloseHandle(listener_mutex);
    return 0;
  }
  // Start a fresh log, permitting readers and preventing other writers.
  FILE *log_stream = _fsopen(log_file.c_str(), "w", _SH_DENYWR);
  if (!log_stream) {
    OutputDebugStringA("[@EQ] cannot open stdout log file\n");
    return 1;
  }
  FILE *log_stdout = nullptr, *log_stderr = nullptr;
  if (freopen_s(&log_stdout, "NUL", "w", stdout) != 0 || _dup2(_fileno(log_stream), _fileno(stdout)) != 0) {
    fclose(log_stream);
    OutputDebugStringA("[@EQ] cannot redirect stdout to log file\n");
    return 1;
  }
  fclose(log_stream);
  setvbuf(stdout, NULL, _IONBF, 0);
  if (freopen_s(&log_stderr, "NUL", "w", stderr) != 0 || _dup2(_fileno(stdout), _fileno(stderr)) != 0) {
    printf("[@EQ] cannot open stderr log file\n");
    return 1;
  }
  setvbuf(stderr, NULL, _IONBF, 0);
  printf("[@EQ] listener %s starting\n", VERSION_STR);
  fflush(stdout);
  WIN32_FILE_ATTRIBUTE_DATA fa0;
  bool ini_found = GetFileAttributesExA(ini.c_str(), GetFileExInfoStandard, &fa0) != 0;
  printf("[@EQ] ini %s %s\n", ini.c_str(), ini_found ? "found" : "missing");
  fflush(stdout);

  CoInitialize(NULL);
  SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_TIME_CRITICAL);

  IMMDeviceEnumerator *en = NULL;
  if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL,
      __uuidof(IMMDeviceEnumerator), (void **)&en))) {
    printf("[@EQ] no device enumerator\n");
    return 1;
  }

  HANDLE reload_ev = CreateEventA(NULL, FALSE, FALSE, NULL);
  HANDLE ini_ev = CreateEventA(NULL, FALSE, FALSE, "Local\\@EQReload");

  WNDCLASSA wc; ZeroMemory(&wc, sizeof(wc));
  wc.lpfnWndProc = HiddenWndProc; wc.hInstance = GetModuleHandleA(NULL);
  wc.hIcon = LoadIconA(wc.hInstance, MAKEINTRESOURCEA(IDI_EQ_LISTENER));
  wc.lpszClassName = "@EQHidden";
  RegisterClassA(&wc);
  HWND hidden = CreateWindowA("@EQHidden", "", 0, 0, 0, 0, 0, NULL, NULL, GetModuleHandleA(NULL), NULL);
  SetWindowLongPtrA(hidden, GWLP_USERDATA, (LONG_PTR)reload_ev);

  Notifier *notifier = new Notifier(reload_ev);
  en->RegisterEndpointNotificationCallback(notifier);

  MasterVolumeBridge master_bridge;
  std::string master_id;
  DWORD master_poll = 0;
  CableSilenceStream cable_silence;
  bool cable_silence_warning = false;
  // Refresh both CABLE Input references after capture recovers or is reinstalled.
  auto refresh_cable_input = [&]() {
    master_id = FindEndpoint(en, eRender, "CABLE Input");
    if (master_id.empty()) master_id = FindEndpoint(en, eRender, "HiFi Cable");
    cable_silence.Close();
    IAudioEndpointVolume *master_control = nullptr;
    if (!master_id.empty()) {
      WCHAR master_wide[512] = {};
      MultiByteToWideChar(CP_UTF8, 0, master_id.c_str(), -1, master_wide, 512);
      IMMDevice *master_device = nullptr;
      if (SUCCEEDED(en->GetDevice(master_wide, &master_device))) {
        master_device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr, (void **)&master_control);
        master_device->Release();
      }
    }
    master_bridge.SetControl(master_control);
  };
  refresh_cable_input();

  IAudioClient *cap_client = nullptr;
  IAudioCaptureClient *cap = nullptr;
  WAVEFORMATEX *cap_fmt = nullptr;
  HANDLE cap_ev = nullptr;
  double cap_rate = 0;
  bool capture_retry = true;
  unsigned capture_tries = 0;
  DWORD capture_last_attempt = GetTickCount() - CAPTURE_RETRY_MS;

  std::string monitor, bound_id, preset;
  IAudioClient *ren_client = NULL;
  IAudioRenderClient *ren = NULL;
  WAVEFORMATEX *ren_fmt = NULL;
  HANDLE ren_ev = NULL;
  IMMDevice *ren_dev = NULL;
  UINT32 ren_buf_frames = 0;
  Bank bank_a, bank_b;
  GraphicInput graphic_input;
  std::vector<Bank> retired_banks;
  std::future<void> retirement_job;
  auto retire_bank = [&](Bank &bank) {
    if (!bank.ready) return;
    retired_banks.push_back(std::move(bank));
    bank = Bank();
  };
  std::future<Bank> design_job;
  std::unique_ptr<Bank> prepared_bank;
  std::vector<Band> requested_bands;
  double requested_preamp = 0;
  bool design_dirty = false;
  unsigned long long design_revision = 0, job_revision = 0;

  double mix = 1.0, mix_step = 0.0;
  bool swap_ch = false;
  double render_rate = 48000.0;
  int render_ch = 2;
  AudioQueue fifo; // bounded interleaved render-channel float frames
  CaptureResampler capture_resampler;
  FILETIME last_ini_write; ZeroMemory(&last_ini_write, sizeof(last_ini_write));
  if (ini_found) last_ini_write = fa0.ftLastWriteTime;
  DWORD last_poll = 0;
  bool render_retry = false, render_warning = false;
  std::string render_warning_endpoint;

  // Discard capture resources and pending samples before a fresh connection.
  // Called on read/open failure and shutdown; no output link is changed.
  auto close_capture = [&]() {
    if (cap_client) cap_client->Stop();
    if (cap) { cap->Release(); cap = nullptr; }
    if (cap_client) { cap_client->Release(); cap_client = nullptr; }
    if (cap_fmt) { CoTaskMemFree(cap_fmt); cap_fmt = nullptr; }
    if (cap_ev) { CloseHandle(cap_ev); cap_ev = nullptr; }
    cap_rate = 0;
    fifo.clear();
    capture_resampler.Reset(0);
    capture_retry = true;
  };

  // Rediscover and start CABLE Output for startup and runtime recovery.
  // Returns S_OK only after Start succeeds, otherwise the failing HRESULT.
  // The caller closes partial resources and retries without blocking messages.
  auto open_capture = [&]() -> HRESULT {
    close_capture();
    std::string capture_id = FindEndpoint(en, eCapture, "CABLE Output");
    if (capture_id.empty()) capture_id = FindEndpoint(en, eCapture, "HiFi Cable");
    if (capture_id.empty()) return AUDCLNT_E_DEVICE_INVALIDATED;
    WCHAR capture_wide[512] = {};
    if (!MultiByteToWideChar(CP_UTF8, 0, capture_id.c_str(), -1, capture_wide, 512)) return HRESULT_FROM_WIN32(GetLastError());
    IMMDevice *capture_device = nullptr;
    HRESULT result = en->GetDevice(capture_wide, &capture_device);
    if (FAILED(result)) return result;
    std::string capture_name = EndpointName(capture_device);
    result = capture_device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr, (void **)&cap_client);
    capture_device->Release();
    if (FAILED(result)) return result;
    result = cap_client->GetMixFormat(&cap_fmt);
    if (FAILED(result)) return result;
    if (!IsFloatFormat(cap_fmt) || !cap_fmt->nSamplesPerSec || !cap_fmt->nChannels) return AUDCLNT_E_UNSUPPORTED_FORMAT;
    cap_ev = CreateEventA(nullptr, FALSE, FALSE, nullptr);
    if (!cap_ev) return HRESULT_FROM_WIN32(GetLastError());
    result = cap_client->Initialize(AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_EVENTCALLBACK, 0, 0, cap_fmt, nullptr);
    if (FAILED(result)) return result;
    result = cap_client->SetEventHandle(cap_ev);
    if (FAILED(result)) return result;
    result = cap_client->GetService(__uuidof(IAudioCaptureClient), (void **)&cap);
    if (FAILED(result)) return result;
    result = cap_client->Start();
    if (FAILED(result)) return result;
    cap_rate = cap_fmt->nSamplesPerSec;
    capture_resampler.Reset(cap_fmt->nChannels);
    capture_retry = false;
    printf("[@EQ] capture: %s\n[@EQ] capture id: %s\n", capture_name.c_str(), capture_id.c_str());
    fflush(stdout);
    return S_OK;
  };

  // Report only the first render error for an outage; recovery resets the flag.
  auto warn_render = [&](const char *message, unsigned detail) {
    if (render_warning) return;
    printf(message, detail);
    fflush(stdout);
    render_warning = true;
  };

  auto open_render = [&](const std::string &endpoint_id) -> bool {
    if (endpoint_id != render_warning_endpoint) {
      render_warning_endpoint = endpoint_id;
      render_warning = false;
    }
    render_retry = true;
    if (ren_client) { ren_client->Stop(); ren_client->Release(); ren_client = NULL; }
    if (ren) { ren->Release(); ren = NULL; }
    if (ren_dev) { ren_dev->Release(); ren_dev = NULL; }
    if (ren_fmt) { CoTaskMemFree(ren_fmt); ren_fmt = NULL; }
    if (ren_ev) { CloseHandle(ren_ev); ren_ev = NULL; }
    if (!endpoint_id.empty()) {
      WCHAR wid[512] = {0};
      MultiByteToWideChar(CP_UTF8, 0, endpoint_id.c_str(), -1, wid, 512);
      if (FAILED(en->GetDevice(wid, &ren_dev))) ren_dev = NULL;
    }
    if (!ren_dev) { warn_render("[@EQ] render endpoint unavailable %08x; retrying output\n", unsigned(AUDCLNT_E_DEVICE_INVALIDATED)); return false; }
    HRESULT hr2 = ren_dev->Activate(__uuidof(IAudioClient), CLSCTX_ALL, NULL, (void **)&ren_client);
    if (FAILED(hr2) || !ren_client) { warn_render("[@EQ] render activate failed %08x; retrying output\n", unsigned(hr2)); return false; }
    hr2 = ren_client->GetMixFormat(&ren_fmt);
    if (FAILED(hr2) || !ren_fmt) { warn_render("[@EQ] render mix format failed %08x; retrying output\n", unsigned(hr2)); return false; }
    if (!IsFloatFormat(ren_fmt)) { warn_render("[@EQ] render format is not float32, tag %u; retrying output\n", unsigned(ren_fmt->wFormatTag)); return false; }
    if (ren_fmt->nChannels > MAX_AUDIO_CHANNELS) {
      warn_render("[@EQ] render format exceeds %u supported channels; retrying output\n", unsigned(MAX_AUDIO_CHANNELS));
      return false;
    }
    IAudioEndpointVolume *master_output = nullptr;
    ren_dev->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr, (void **)&master_output);
    master_bridge.SetOutput(master_output);
    render_rate = ren_fmt->nSamplesPerSec;
    render_ch = ren_fmt->nChannels;
    fifo.Reset(size_t(render_rate) * render_ch * AUDIO_QUEUE_SECONDS, render_ch);
    capture_resampler.Reset(cap_fmt ? cap_fmt->nChannels : 0);
    graphic_input = GraphicInput(render_rate, render_ch);
    ren_ev = CreateEventA(NULL, FALSE, FALSE, NULL);
    hr2 = ren_client->Initialize(AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_EVENTCALLBACK, 0, 0, ren_fmt, NULL);
    if (FAILED(hr2)) { warn_render("[@EQ] render init failed %08x; retrying output\n", unsigned(hr2)); return false; }
    hr2 = ren_client->SetEventHandle(ren_ev);
    if (FAILED(hr2)) { warn_render("[@EQ] render event failed %08x; retrying output\n", unsigned(hr2)); return false; }
    hr2 = ren_client->GetService(__uuidof(IAudioRenderClient), (void **)&ren);
    if (FAILED(hr2) || !ren) { warn_render("[@EQ] render service failed %08x; retrying output\n", unsigned(hr2)); return false; }
    hr2 = ren_client->GetBufferSize(&ren_buf_frames);
    if (FAILED(hr2) || ren_buf_frames == 0) { warn_render("[@EQ] render buffer failed %08x; retrying output\n", unsigned(hr2)); return false; }
    return true;
  };

  auto reload_preset = [&]() {
    std::string mon = CurrentMonitor();
    std::string p = IniStr(ini, "Playback", "Preset", "Default");
    if (p.empty()) p = "Default";
    std::string monitor_name = IniStr(ini, "Monitors", mon.c_str(), "");
    std::string output_key = "Output_" + monitor_name;
    std::string ep = IniStr(ini, p.c_str(), output_key.c_str(), "");
    std::string mode_key = "Mode_" + monitor_name;
    std::string mode = IniStr(ini, p.c_str(), mode_key.c_str(), IniStr(ini, p.c_str(), "Mode", "10band").c_str());
    std::string section = p + "_" + monitor_name + "_" + mode;
    if (ep.empty()) {
      render_retry = render_warning = false;
      render_warning_endpoint.clear();
      if (ren_client) { ren_client->Stop(); ren_client->Release(); ren_client = NULL; }
      if (ren) { ren->Release(); ren = NULL; }
      if (ren_ev) { CloseHandle(ren_ev); ren_ev = NULL; }
      bound_id.clear(); monitor = mon;
      printf("[@EQ] monitor %s has no Output link; select an Output and Link monitor\n", mon.c_str());
      return;
    }
    bool new_dev = (ep != bound_id) || !ren_client || render_retry;
    if (new_dev) {
      if (!open_render(ep)) return;
      bound_id = ep;
      fifo.clear();
      retire_bank(bank_a); retire_bank(bank_b);
      mix = 1.0;
      HRESULT render_start_result = ren_client->Start();
      if (FAILED(render_start_result)) {
        warn_render("[@EQ] render start failed %08x; retrying output\n", unsigned(render_start_result));
        return;
      }
      render_warning = false;
      printf("[@EQ] render: %s\n", EndpointName(ren_dev).c_str());
    }
    render_retry = false;
    std::vector<Band> bands; double preamp_db = 0;
    if (!LoadPreset(ini, section, bands, preamp_db)) {
      printf("[@EQ] preset %s missing, flat EQ until the UI saves\n", p.c_str());
      fflush(stdout);
      static const double iso10[10] = {31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000};
      bands.clear();
      for (int i = 0; i < 10; i++) { Band b; b.freq = iso10[i]; bands.push_back(b); }
      preamp_db = 0;
    }
    swap_ch = IniStr(ini, "OutputSwap", ep.c_str(), "0") != "0";
    bool same_curve = bands.size() == requested_bands.size() && preamp_db == requested_preamp;
    if (same_curve) {
      for (size_t i = 0; i < bands.size(); ++i)
        if (bands[i].freq != requested_bands[i].freq || bands[i].gain_db != requested_bands[i].gain_db) { same_curve = false; break; }
    }
    if (!new_dev && mon == monitor && p == preset && same_curve) return;
    monitor = mon; preset = p;
    requested_bands = std::move(bands);
    requested_preamp = preamp_db;
    ++design_revision;
    design_dirty = true;
    if (prepared_bank) retire_bank(*prepared_bank);
    prepared_bank.reset();
    printf("[@EQ] monitor %s preset %s bands %d\n", mon.c_str(), p.c_str(), (int)requested_bands.size());
    fflush(stdout);
  };

  reload_preset();
  bool running = true;

  while (running) {
    // Large banks are released by a background task, including stale designs.
    if (retirement_job.valid() && retirement_job.wait_for(std::chrono::seconds(0)) == std::future_status::ready) retirement_job.get();
    if (!retirement_job.valid() && !retired_banks.empty()) {
      retirement_job = std::async(std::launch::async, [retired = std::move(retired_banks)]() mutable {
        SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_BELOW_NORMAL);
        retired.clear();
      });
      retired_banks.clear();
    }
    DWORD capture_now = GetTickCount();
    if (capture_retry && capture_now - capture_last_attempt >= CAPTURE_RETRY_MS) {
      capture_last_attempt = capture_now;
      HRESULT capture_open_result = open_capture();
      if (FAILED(capture_open_result)) {
        close_capture();
        if (capture_tries % 5 == 0) {
          printf("[@EQ] capture unavailable %08x; retrying CABLE Output.", unsigned(capture_open_result));
          if (capture_open_result == E_ACCESSDENIED) printf(" Check microphone access and untick Listen.");
          printf("\n");
          fflush(stdout);
        }
        ++capture_tries;
      } else {
        capture_tries = 0;
        refresh_cable_input();
      }
    }
    // Drain capture as soon as its packets arrive, independently of rendering.
    // Recovery replaces stream events; build the wait list from current handles.
    HANDLE wait_list[5] = { reload_ev, ini_ev };
    DWORD wait_count = 2;
    if (cap_ev) wait_list[wait_count++] = cap_ev;
    if (ren_ev) wait_list[wait_count++] = ren_ev;
    if (cable_silence.Event()) wait_list[wait_count++] = cable_silence.Event();
    DWORD w = MsgWaitForMultipleObjects(wait_count, wait_list, FALSE, 500, QS_ALLINPUT);
    MSG m;
    while (PeekMessageA(&m, NULL, 0, 0, PM_REMOVE)) {
      if (m.message == WM_QUIT) running = false;
      TranslateMessage(&m); DispatchMessageA(&m);
    }
    if (!running) break;
    if (w == WAIT_OBJECT_0 || w == WAIT_OBJECT_0 + 1) reload_preset();
    // Check the ini only while the app runs. @EQApp.exe registers the
    // @EQApp mutex; the UI also signals ini_ev on every save so moves apply at
    // once. Switches above always re-read, app or not.
    DWORD now = GetTickCount();
    if (now - last_poll > 500) {
      last_poll = now;
      if (!cable_silence.Event()) {
        if (cable_silence.Open(en, master_id)) {
          printf("[@EQ] CABLE Input playback kept active with silence\n");
          cable_silence_warning = false;
        } else if (!cable_silence_warning) {
          printf("[@EQ] could not keep CABLE Input active; retrying in background\n");
          cable_silence_warning = true;
        }
      }
      // Retry unavailable outputs without depending on another device notification.
      if (render_retry) reload_preset();
      HANDLE app = OpenMutexA(SYNCHRONIZE, FALSE, "Local\\@EQApp");
      if (app) {
        CloseHandle(app);
        WIN32_FILE_ATTRIBUTE_DATA fa;
        if (GetFileAttributesExA(ini.c_str(), GetFileExInfoStandard, &fa)) {
          if (CompareFileTime(&fa.ftLastWriteTime, &last_ini_write) != 0) {
            last_ini_write = fa.ftLastWriteTime;
            reload_preset();
          }
        }
      }
    }
    // Only completed jobs are collected; FIR construction never blocks rendering.
    if (design_job.valid() && design_job.wait_for(std::chrono::seconds(0)) == std::future_status::ready) {
      Bank result = design_job.get();
      if (job_revision == design_revision) prepared_bank = std::make_unique<Bank>(std::move(result));
      else retire_bank(result);
    }
    if (design_dirty && !design_job.valid()) {
      auto points = requested_bands;
      double gain = requested_preamp, rate = render_rate;
      int channels = render_ch;
      job_revision = design_revision;
      design_dirty = false;
      design_job = std::async(std::launch::async, [points = std::move(points), gain, rate, channels]() {
        SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_BELOW_NORMAL);
        Bank result;
        BuildBank(result, points, gain, rate, channels);
        return result;
      });
    }
    DWORD master_now = GetTickCount();
    if (master_now - master_poll >= MASTER_VOLUME_POLL_MS) {
      master_poll = master_now;
      master_bridge.Sync();
    }
    if (cable_silence.Event() && !cable_silence.Fill()) {
      cable_silence.Close();
      if (!cable_silence_warning) printf("[@EQ] CABLE Input silence stream interrupted; retrying in background\n");
      cable_silence_warning = true;
    }
    // Drain capture packets into the fifo with channel mapping.
    UINT32 next = 0;
    HRESULT capture_result = cap ? cap->GetNextPacketSize(&next) : S_OK;
    while (SUCCEEDED(capture_result) && next > 0) {
      BYTE *data = NULL; UINT32 frames = 0; DWORD flags = 0;
      capture_result = cap->GetBuffer(&data, &frames, &flags, NULL, NULL);
      if (FAILED(capture_result)) break;
      if (ren_client && ren && !render_retry && frames > 0) {
        const float *samples = (const float *)data;
        bool silent = (flags & AUDCLNT_BUFFERFLAGS_SILENT) || !samples;
        double step = capture_resampler.Step(cap_rate, render_rate, frames, fifo.size() / render_ch, ren_buf_frames);
        capture_resampler.Append(samples, frames, silent, render_ch, step, fifo);
      } else {
        // Capture must still be released while no usable output consumes it.
        fifo.clear();
        capture_resampler.Reset(cap_fmt->nChannels);
      }
      capture_result = cap->ReleaseBuffer(frames);
      if (FAILED(capture_result)) break;
      capture_result = cap->GetNextPacketSize(&next);
    }
    if (FAILED(capture_result)) {
      printf("[@EQ] capture lost %08x; reopening CABLE Output\n", unsigned(capture_result));
      fflush(stdout);
      close_capture();
      capture_tries = 0;
      capture_last_attempt = GetTickCount();
    }
    // Fill one render buffer.
    if (ren_client && ren && !render_retry) {
      UINT32 pad = 0;
      HRESULT render_result = ren_client->GetCurrentPadding(&pad);
      if (FAILED(render_result)) {
        warn_render("[@EQ] render padding failed %08x; reopening output\n", unsigned(render_result));
        render_retry = true;
        continue;
      }
      UINT32 want = ren_buf_frames > pad ? ren_buf_frames - pad : 0;
      if (want > 0) {
        BYTE *out = NULL;
        render_result = ren->GetBuffer(want, &out);
        if (FAILED(render_result) || !out) {
          warn_render("[@EQ] render get buffer failed %08x; reopening output\n", unsigned(render_result));
          render_retry = true;
          continue;
        }
        if (out) {
          float *f = (float *)out;
          size_t have = fifo.size() / render_ch;
          for (UINT32 i = 0; i < want; i++) {
            if (prepared_bank && mix >= 1.0 && graphic_input.position == 0) {
              CalculateBankBlock(*prepared_bank, graphic_input);
              retire_bank(bank_a);
              bank_a = std::move(bank_b);
              bank_b = std::move(*prepared_bank);
              prepared_bank.reset();
              mix = bank_a.ready ? 0.0 : 1.0;
              mix_step = 1.0 / (XFADE_SEC * render_rate);
            }
            float frame[MAX_AUDIO_CHANNELS] = {0};
            if ((size_t)i < have)
              for (int ch = 0; ch < render_ch && ch < MAX_AUDIO_CHANNELS; ch++) frame[ch] = fifo[i * render_ch + ch];
            for (int ch = 0; ch < render_ch; ++ch) graphic_input.state[ch].current[graphic_input.position] = frame[ch];
            if (mix < 1.0 && bank_a.ready && bank_b.ready) {
              float fa_[MAX_AUDIO_CHANNELS], fb[MAX_AUDIO_CHANNELS];
              for (int ch = 0; ch < render_ch && ch < MAX_AUDIO_CHANNELS; ch++) { fa_[ch] = frame[ch]; fb[ch] = frame[ch]; }
              RunBank(bank_a, fa_, render_ch, graphic_input.position);
              RunBank(bank_b, fb, render_ch, graphic_input.position);
              for (int ch = 0; ch < render_ch && ch < MAX_AUDIO_CHANNELS; ch++) frame[ch] = (float)(fa_[ch] * (1.0 - mix) + fb[ch] * mix);
              mix += mix_step;
              if (mix >= 1.0) mix = 1.0;
            } else {
              if (!bank_b.ready) std::fill(frame, frame + render_ch, 0.0f);
              else RunBank(bank_b, frame, render_ch, graphic_input.position);
              mix = 1.0;
            }
            if (++graphic_input.position == GRAPHIC_BLOCK) {
              CompleteGraphicBlock(graphic_input);
              if (bank_b.ready) CalculateBankBlock(bank_b, graphic_input);
              if (mix < 1.0 && bank_a.ready) CalculateBankBlock(bank_a, graphic_input);
            }
            if (mix >= 1.0) retire_bank(bank_a);
            if (swap_ch && render_ch >= 2) { float t = frame[0]; frame[0] = frame[1]; frame[1] = t; }
            for (int ch = 0; ch < render_ch; ch++) f[i * render_ch + ch] = frame[ch];
          }
          if (have > 0) {
            size_t drop = (have < want ? have : want) * render_ch;
            fifo.Drop(drop);
          }
          render_result = ren->ReleaseBuffer(want, 0);
          if (FAILED(render_result)) {
            warn_render("[@EQ] render release buffer failed %08x; reopening output\n", unsigned(render_result));
            render_retry = true;
          }
        }
      }
    }
  }

  cable_silence.Close();
  close_capture();
  if (ren_client) ren_client->Stop();
  en->UnregisterEndpointNotificationCallback(notifier);
  notifier->Release();
  DestroyWindow(hidden);
  CloseHandle(reload_ev); CloseHandle(ini_ev);
  if (ren_ev) CloseHandle(ren_ev);
  printf("[@EQ] stopped\n");
  ReleaseMutex(listener_mutex);
  CloseHandle(listener_mutex);
  return 0;
}
