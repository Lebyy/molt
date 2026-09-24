<div align="center">

<img src="assets/px-title.png" alt="MOLT. Local copies leave." width="625">

<p>The one in the cloud stays.</p>

<p>
  <a href="#install"><strong>Install</strong></a>
  &nbsp;·&nbsp;
  <a href="#use">Use</a>
  &nbsp;·&nbsp;
  <a href="#how">How it works</a>
  &nbsp;·&nbsp;
  <a href="#saved">Saved</a>
</p>

</div>

<br>

<table>
  <tr>
    <td width="33%" align="center"><img src="assets/molt-icon.png" alt="Frosted glass file shedding a shell" width="220"></td>
    <td width="67%">
      <h3>A file should visit. It should not move in.</h3>
      <p>macOS will download an iCloud Drive file when you open it, then keep the bytes around because the disk is not full. Molt drops that local copy a few minutes after you are done. Open it again later and it downloads again.</p>
    </td>
  </tr>
</table>

<br>

<div align="center">
  <img src="assets/molt-flow.png" alt="Three glass documents: present, opening, then only vapor" width="880">
  <br>
  <img src="assets/pass.png" alt="Open, close, molt" width="880">
</div>

<h2 id="install"><img src="assets/px-install.png" alt="Install" height="52"></h2>

<p>macOS 14 or newer. Xcode or the Swift command line tools.</p>

<pre><code>git clone https://github.com/Lebyy/molt.git
cd molt
make install
</code></pre>

<p><code>make install</code> builds a release binary with warnings as errors, copies it to <code>~/Library/Application Support/molt</code>, signs that copy, and registers a login agent. It also turns on Optimize Mac Storage (<code>com.apple.bird</code> <code>optimize-storage</code>), which is the setting that downloads a file only when you open it.</p>

<p>The first time the agent runs, macOS may ask for iCloud Drive access. Allow it. Without that, molt can see the folder and still not release anything.</p>

<h3><img src="assets/px-byhand.png" alt="By hand" height="40"></h3>

<pre><code>swift build -c release -Xswiftc -warnings-as-errors
.build/release/molt install
</code></pre>

<h3><img src="assets/px-stop.png" alt="Stop" height="40"></h3>

<pre><code>.build/release/molt uninstall
</code></pre>

<p>That unloads the agent and deletes its plist. The log file stays.</p>

<h2 id="use"><img src="assets/px-use.png" alt="Use" height="52"></h2>

<table>
  <tr><th>Command</th><th>What it does</th></tr>
  <tr><td><kbd>molt</kbd></td><td>Release local copies once, now</td></tr>
  <tr><td><kbd>molt install</kbd></td><td>Same thing at login, then every 3 minutes</td></tr>
  <tr><td><kbd>molt status</kbd></td><td>Whether the agent is loaded, plus the last log lines</td></tr>
  <tr><td><kbd>molt uninstall</kbd></td><td>Stop the agent</td></tr>
  <tr><td><kbd>molt help</kbd></td><td>The same list, in the terminal</td></tr>
</table>

<p>A pass names only the top level of iCloud Drive, the folders you see in the sidebar. Evicting a folder tells the system to drop the local copies inside it. Walking every nested file through File Provider stalls, so molt does not do that.</p>

<p>A folder that is busy, or is not an iCloud item, is left in place and written to the log as <code>kept</code>.</p>

<pre><code>tail -f ~/Library/Application\ Support/molt/molt.log
</code></pre>

<h2 id="how"><img src="assets/px-how.png" alt="How it works" height="48"></h2>

<ol>
  <li>You open a file. macOS downloads it. That part is Optimize Mac Storage, not molt.</li>
  <li>You close it. The cloud file was never the thing being removed.</li>
  <li>About every 3 minutes, <code>FileManager.evictUbiquitousItem</code> drops the local bytes of each top-level iCloud Drive item.</li>
</ol>

<p>Molt does not upload, rename, or delete anything in iCloud. It does not touch the Photos library. Desktop and Documents are included only when they already live inside iCloud Drive.</p>

<h2 id="saved"><img src="assets/px-saved.png" alt="Saved" height="48"></h2>

<div align="center">
  <img src="assets/stats.png" alt="186 GB of local copies back on the Mac. Nothing deleted from iCloud." width="880">
</div>

<p>Optimize Mac Storage is supposed to let go of a file after you close it. It does not, once the disk has room. On this Mac that was 186 GB of copies already sitting in iCloud. Molt took the local bytes back. The cloud files stayed.</p>

<h2><img src="assets/px-layout.png" alt="Layout" height="48"></h2>

<pre><code>Sources/MoltCore        command parsing, the launch agent plist, the log
Sources/molt            the command line: evict, install, status
Sources/molt-selfcheck  the checks (XCTest is not in the command line tools)
assets                  renders and the diagrams above
</code></pre>

<pre><code>make test
</code></pre>

<p>MIT. Copyright 2026 Lebyy.</p>
