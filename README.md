# [@EQ](https://corz.org/windows/software/@EQ/)

<div>
<div> <a href="https://corz.org/windows/software/@EQ/#section-Download" title="Click here to go straight to the downloads!"><img alt="@EQ icon/logo, in super-large 256 pixel size!" src="https://corz.org/windows/software/@EQ/img/@EQ.webp"/></a>
</div>
<h4>Your speakers follow your screen, <em>automatically</em>.
</h4>
<h2>What is @EQ?
</h2>
<p>@EQ is a simple app designed to do one simple thing: Switch your speaker setup when you switch your primary monitor.
</p>
<p>You could also use it as a preset-capable audio equaliser, but auto-switching is @EQ's main purpose, for folk like me who use their PC also as their movie player (or whatever) on a different screen, with different speakers.
</p>
<p>I used to use Equalizer APO for this, but I could never get the darned thing to work <em>automatically</em>, and having to switch EQ &amp; preamp levels manually when we switch to the "movie screen" was becoming tedious (my desktop speakers sound very different to our "movie" speakers, without EQ adjustment). And of course, switching back again.
</p>
<p>@EQ, once setup, will automatically and painlessly set your audio output, EQ + preamp levels and audio channels on a per-monitor basis, with <em>zero</em> user interaction.
</p>
<p>@EQ comes in two parts. A listener which runs in the background (using minimal resources), and a font-end editor, which you can use to make changes to your settings, load and save presets, etc..
</p>
<p> Stereo-only, for now.
</p>
<h2>Components..
</h2>
<ul>
<li>
<h2>The Wire
</h2>
<p>@EQ uses the <a href="https://vb-audio.com/Cable/" title="VB-CABLE is Donationware. If you find this useful you might consider a donation.">VB-Audio virtual cable</a>; basically a driver; which you will need to install and setup. This is pretty simple. See the <a href="https://corz.org/windows/software/@EQ/#CABLE-setup" title="Setup CABLE">CABLE setup section</a>.
</p>
<p>CABLE Input is the playback end your apps play into. CABLE Output is the recording end the listener reads.
</p>
</li>
<li>
<h2>The Listener
</h2>
<p><code>@EQListener.exe</code> captures the CABLE input; using WASAPI; filters it to your specifications and plays it through the linked Output.
</p>
</li>
<li>
<h2>The App
</h2>
<p><code>@EQ.exe</code> enables you to edit audio presets and links monitors to speakers. The app updates the (ini) settings for the listener to read and apply.
</p>
<p>When @EQ.exe isn't running, the listener stops checking the ini file until you switch monitors, switch output device, or change the "default" output device.
</p>
</li>
</ul> <br/> <br/>
<h2>CABLE setup:
</h2>
<p>First, install the <a href="https://vb-audio.com/Cable/" title="VB CABLE - yes a stupid name. Good luck searching the web for help!">VB-Audio virtual cable</a> as Admin. It adds two sound devices to your system audio setup: CABLE Input (ignore the 16ch variant) on the playback side and CABLE Output on the recording side. You will need to reboot to complete the installation.
</p>
<h2>Once CABLE is installed:
</h2>
<ul>
<li>
<h2>Microphone privacy
</h2>
<p>Windows Settings (Win+I) &gt; Privacy and security &gt; Microphone. Enable "Microphone access" and "Let desktop apps access the microphone". With either off, audio captures fail and the listener instead creates a <code>capture denied</code> entry to its log. CABLE counts as a microphone here. There are technical resons for this, outside the scope of this document.
</p>
<p>No program can work around this switch, so if you want <code>@EQ</code> to work, that's your only option. It doesn't matter if you have an actual microphone or not; because of the way CABLE routes audio, these setting need to be enabled for CABLE to work with <code>@EQ</code>.
</p>
</li>
<li>
<h2>Default playback
</h2>
<p>Open Sound settings, Playback tab. Right-click CABLE Input, Set as Default Device.
</p>
<p>Once installed and selected as the default output device, every app that sends audio to the "default" device will now use CABLE for its output.
</p>
<p>To test if CABLE is working, head to the Sound &gt; Recording tab (best to use <span title="Use Win+R and enter this in the dialog">mmsys.cpl</span> for this, as the newer Windows audio control panel is rubbish), open CABLE Output properties &gt; Listen tab &gt; check "Listen", and below select your current speakers (ensure you have some audio playing), apply.
</p>
<p>If all goes well, you should hear your audio. Good. Test complete. Now disable Listen and select "Default Playback Device", move on..
</p>
</li>
</ul>
<p>Any issues, check the <code>@EQListener.log</code> (in <span>%APPDATA%\corz\@EQ</span>) for details. <br/> <br/>
</p>
<h2>@EQ App:
</h2> <img alt="The main @EQ interface" src="https://corz.org/windows/software/@EQ/img/@EQ_Main_Window.webp" title="The main @EQ Interface"/>
<ul>
<li>There is a choice of 5-band, 10-band, 15-band and parametric EQ controls. The parametric EQ can have up to 32 independantly configurable frequency band sliders (the default is 20); you can add and delete them as required.
</li>
<li>Draw a marquee around any amount of sliders to select them; you can then can drag them all <em>together</em>.
</li>
<li>Select any slider (or its rail, which moves the slider to that point) then move your pointer left or right to "draw" an EQ curve.
</li>
<li>If you edit a curve in one mode, when you switch to a new mode, so long as you haven't edited that mode already, your curve will be retained; recalculated to the new number of bands. Works both ways, so you can setup a simple curve in 5 or 10 band EQ, then transfer it to a 20 band paramteric EQ for finer control, or whatever.
</li>
<p>This magic will also be applied of you flatten the sliders in your current mode, switch to a different mode with a curve you like, and back. Voila!
</p>
<li>Whatever you set for the lowest/highest frequency values is used for all values beyond (aka. "flat outside"). So, for example, if you need to clamp the low frequency output on your speakers at 60Hz, create a slider at 60Hz (set to 0) and another at 61Hz (or whatever), where your real settings will begin.
<p>Similarly, if you delete all-but-one of your parametric EQ bands, the remaining band effectively becomes a volume control, spanning all EQ bands; pointless, but illustrates the point.
</p>
</li>
<li>Parametric mode has extra controls under the sliders. The band's frequency is editable, and underneath that a grey slider thumb which you can use to drag the band up and down the frequency range. Other sliders will move to accommodate.
<p>The current frequency of the band is calculated continuously by the pointer's current position on a logarithmic scale between its <em>original</em> position and the next band's position, in other words, if you slide half way to the next band and let go (the thumb snaps back to its original location), doing that same thing action again would shift the band's frequency <em>half</em> what it did last time; you can get sliding accuracy down to 1Hz this way. It's easier done than said.
</p>
</li>
<li>The frequency graph updates live as you move a parametric band around.
</li>
<li>Hold down the Ctrl key to transform the grey thumbs into a delete buttons, clicking one deletes that band (you can right-click the slider thumbs for this, too).
</li>
<li>Like Equalizer APO, the position of any frequency is measured on a logarithmic axis between your selected points, basically drawing straight lines between them on the log axis, with linear interpolation. Move a slider and every frequency point between that slider and its neighbours will rise or fall relative to your change.
</li>
<li>A graphical display of the current frequency response updates instantly on all changes.
</li>
<li>All changes are saved live, there is no "Save" button. If you want to mess about with a preset, best to use the "Duplicate" function.
</li>
<li>There is a rudementary undo facility (<code>Ctrl+Z</code>, as usual), so any slider and preamp changes can be reverted.
</li>
<li>There is no "redo" and no "levels" of undo.
<p>Only your most recent action is stored; <em>however</em> undo will revert multi-sliders actions like flatten operations, "drawn" curves <em>and</em> moving <em>multiple</em> (marquee selected) sliders together, as well as deleting a slider and moving it around the frequency band. So, fairly useful, but only for <em>one action</em>.
</p>
</li>
<li>Right-click the preset combo to rename a preset, export a preset, or sort the list.
<p>An unsorted preset list shows in the creation order. The "Default" item is always at the top. You can delete the default preset, or create your own, but if it exists it's always at the top.
</p>
</li>
<li>Right click on any monitor in the list to set a "friendly" name for that screen. Same story for the Outputs combo; something like "NEC &gt; Hifi" is much more useful than well, <em>whatever it was.</em>
</li>
<li>Click and drag blank areas (or the frequency graph) to move the window around.
</li>
<li> <span>Presets</span>
<p>You can of course save presets for later use. These are stored along with all @EQ settings, in your <code>@EQ.ini</code>.
</p>
<p><em>Everything</em> is saved inside the preset, monitors and their selected audio output and for each, EQ curves, preamp levels and channel swap settings for <em>every</em> mode you edited (5 Band, 10 Band, 15 Band and Parametric; each monitor potentially creating four different curves in your ini for each preset), the current mode being the one that is applied.
</p>
<p>The estimated upper limit to the number of monitors @EQ can support inside one preset is around 270, depending on how your hardware is named inside Windows OS. I did not test this.
</p>
</li>
<li> <span>Import / Export</span>
<p>You can import presets from an ini file or export all your presets to a file. Simple as that.
</p>
<p>Right-click the preset combo to export only the current preset.
</p>
</li>
</ul> <br/>
<div> <img alt="@EQ listener icon/logo, in super-large 256 pixel size" src="https://corz.org/windows/software/@EQ/img/@EQ_Listener.webp"/>
</div>
<h2>The Listener:
</h2>
<p>The Listener is written in C++ for quickness. Processing kHz audio on a GHz PC is fairly trivial, but still something we want done at the lowest levels, with as many nice optimizations as possible. Enjoy!
</p>
<p>The listener accepts a few command-line parameters:
</p>
<ul>
<li>
<p>--list
</p>
<p>list render endpoints (audo outputs) as id|name
</p>
</li>
<li>
<p>--default
</p>
<p>reports DefaultOutput=id
</p>
</li>
<li>
<p>--monitor
</p>
<p>print current monitor id
</p>
</li>
<li>
<p>--ini <path> </path>
</p>
<p>use a different ini file (defaults to <code>%APPDATA%\corz\@EQ\@EQ.ini</code>)
</p>
</li>
<li>
<p>--help
</p>
<p>shows this list
</p>
</li>
</ul>
<p>@EQListener never writes to your ini file, it only reads. When the @EQ app is open it does this every 500ms, so your changes happen live.
</p>
<p>As mentioned, the listener logs to <span>%APPDATA%\corz\@EQ</span>. This log is wiped on every launch.
</p>
<p>@EQListener.exe runs as a Windows app, but in the background, which is why if you try run it in a shell, you won't see any output.
</p>
<p>If you want to capture the output from the listener, do something like this:
</p>
<p>python -c "import subprocess; print(subprocess.run([r'C:\Program Files\corz\@EQ\@EQListener.exe', '--help'], capture_output=True, text=True).stdout, end='')" <br/> <br/>
</p>
<h2>In operation..
</h2>
<p>When you switch screens, the listener reads the new screen ID, looks up its link in your <code>@EQ.ini</code> (config) file, opens the linked audio output and then loads your saved slider values (with a 200ms crossfade).
</p>
<p>The listener watches for monitor changes, sound device changes and default device changes; so docking, undocking, and display switches are (hopefully!) all covered.
</p>
<p><strong>Note:</strong> If a screen has no linked audio output, you get <strong>silence</strong>, and in @EQ, an intentionally annoying message telling you how to fix this (basically; select a Monitor, select an Output, Link them). <br/> <br/>
</p>
<h2>Notes:
</h2>
<ul>
<li>If you have multiple monitors connected simultaneously, the "Primary" monitor's linked output is the one @EQ will use.
</li>
<li>Only one listener can run at a time. If you launch a second copy, it will exit immediately.
</li>
<li>The <code>@EQ</code> app saves settings to your ini file, the listener reads that ini file regularly and applies its settings. Simple as that.
<p>If you really wanted to, you could ignore The <code>@EQ</code> app and edit your ini file manually and everything will work 100%, but that's a lot less fun. You could also create a different app to control the listener.
</p>
</li>
<li>If you have old APO presets you want to use in <code>@EQ</code>, ask your AI to convert them to <code>@EQ</code>; it is a trivial task, as they share similar methodology.
</li>
</ul> <br/>
<h2>Requirements:
</h2>
<ul>
<li><a href="https://vb-audio.com/Cable/" title="VB CABLE - yes a stupid name. Good luck searching for help!">VB-Audio virtual cable</a> installed, CABLE Input set as Default Playback.
</li>
<li>Windows microphone access <em>and</em> desktop apps access enabled.
</li>
<li>The "Listen" checkbox on CABLE Output (Windows sound &gt; recorder) must be <em>unchecked</em> in use, or you will get double audio, at best.
</li>
</ul>
<h2>Download @EQ..
</h2>
<div>
<div> <a href="https://corz.org/public/machine/Windows/Software/%40EQ/%40EQ.zip?download" title="Download and use @EQ"> <span>download</span>  <span><img alt="Image of big cardboard box, containing the @EQ package (zip), well, the image is of a parcel, with the @EQ logo overlayed on one side, but you get the idea." src="https://corz.org/windows/software/@EQ/img/@EQ.webp"/></span></a> <br/> <span>@EQ</span>
</div>
<p><a href="https://corz.org/public/machine/Windows/Software/%40EQ/%40EQ.zip?view&amp;clean=true" title="Check out the files inside this Zip!">click to see zip archive contents</a>
</p>
<div title="click here to check out the app responsible for these fine hashes!"><strong>LIVE Hashes..</strong><br/># made with checksum.. 64-bit edition. # from corz.org.. https://corz.org/windows/software/checksum/ # #sha2#@EQ.zip#2026.11.05@10.19:09 82c8a05ab8d087a6f389333f5862ea39e77ee0502521d7ddebc676e9c9821f0b *@EQ.zip
</div>
</div>
<h2>Sauce..
</h2>
<p>Check out the source files <a href="https://corz.org/machine/Windows/Software/%40EQ/Source/" title="@EQ Source files, and more..">here</a>
</p>
<p>Or grab a zip of everything; C++ listener and AutoIt front-end app, with all includes, icons, resources and so on, ready-to-build, here..
</p>
<div>
<div> <a href="https://corz.org/public/machine/Windows/Software/%40EQ/%40EQ_Source.zip?download" title="Download @EQ source pack, for free.."> <span>download</span>  <span><img alt="Image of big cardboard box, containing the @EQ_Source package (zip), well, the image is of a parcel, with the @EQ_Source logo overlayed on one side, but you get the idea." src="https://corz.org/img/windows/zipped-au3-AutoIt-Source-document.png"/></span></a> <br/> <span>@EQ Source</span>
</div>
<p><a href="https://corz.org/public/machine/Windows/Software/%40EQ/%40EQ_Source.zip?view&amp;clean=true" title="Check out the files inside this Zip!">click to see zip archive contents</a>
</p>
<div title="click here to check out the app responsible for these fine hashes!"><strong>LIVE Hashes..</strong><br/># made with checksum.. 64-bit edition. # from corz.org.. https://corz.org/windows/software/checksum/ # #sha2#@EQ_Source.zip#2026.11.05@10.29:25 0135ef57c7bca5f57ed7bbd8f85dfb86db3991241324303392fb2d425f3ad977 *@EQ_Source.zip
</div>
</div>
</div>

## While I try to keep this Git repo up-to-date, the latest source can always be found [here](https://corz.org/windows/software/@EQ/)
