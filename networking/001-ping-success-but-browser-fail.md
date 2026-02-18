# 001 - Browser can't access GitHub.com but ping works

## Problem
I was able to `ping github.com` successfully from my terminal, which confirmed network connectivity.  
However, GitHub was not accessible from any browser tabs (showing site not reachable), except one that was running through a VPN.

## Root Cause
The issue was not with the network itself but with the browser.  
Frequent VPN switching had left cached DNS records and possibly proxy settings inside the browser.  
As a result, the browser tried to resolve GitHub through stale or broken DNS entries, while the system-level ping used fresh DNS resolution.

## Solution
1. Clear the browser's DNS cache:
   - For Chrome/Edge: visit `chrome://net-internals/#dns` → **Clear host cache**.
   - For Brave: `brave://net-internals/#dns`
2. Flush the system DNS cache (Windows):
   ```cmd
   ipconfig /flushdns
    ```
3. Restart the browser and test again.

After clearing the DNS cache, GitHub opened normally without VPN.

## Notes

* Switching between different VPNs often causes browsers to cache stale DNS entries.
* As a quick check, always try direct access one of GitHub’s IPs (`https://140.82.121.4/`) to differentiate between DNS vs network issues.
* If this happens often, consider resetting the browser’s network stack or uninstalling unused VPN adapters from Windows network settings.

## New Learning Unlocked
- **Ping vs Browser DNS**: Ping uses the OS DNS resolver, while browsers often cache their own DNS. That’s why ping worked but the browser failed.  
- **Impact of VPN switching**: Rapidly switching VPNs can leave behind stale DNS and proxy configs that only affect browsers.  
- **Cross-platform awareness**: Flushing DNS is different on Windows vs Linux (e.g., `ipconfig /flushdns` vs `systemd-resolve --flush-caches`).

## Realization
- While checking Chrome’s DNS lookup page, I noticed that the resolved IPs shown there were exactly the same as those from the `nslookup` command in the terminal.  
- I already knew how `nslookup` works, but this gave me clarity that both tools are just showing the same resolver output in different interfaces.  

