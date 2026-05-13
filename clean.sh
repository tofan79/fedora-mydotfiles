#!/bin/bash

echo "========================================="
echo "         FEDORA SYSTEM CLEANUP"
echo "========================================="

echo -e "\n[1/8] DNF cache (keep latest 2 kernels)..."
sudo dnf clean all 2>/dev/null && echo "  ✔ Cache cleaned"
sudo dnf autoremove -y 2>&1 | tail -1 | grep -q "Complete" && echo "  ✔ Orphans removed" || echo "  ✔ No orphans"

echo -e "\n[2/8] mise cache..."
rm -rf ~/.local/share/mise/http-tarballs/* 2>/dev/null && echo "  ✔ mise tarballs cleaned"
mise cache clear 2>/dev/null && echo "  ✔ mise cache cleared"

echo -e "\n[3/8] JetBrains Toolbox cache..."
rm -rf ~/.local/share/JetBrains/Toolbox/cache/* 2>/dev/null && echo "  ✔ Toolbox cache cleaned"
rm -rf ~/.cache/JetBrains/* 2>/dev/null && echo "  ✔ JetBrains cache cleaned"

echo -e "\n[4/8] System temp..."
sudo rm -rf /tmp/* 2>/dev/null
sudo rm -rf /var/tmp/* 2>/dev/null
sudo journalctl --vacuum-time=3d 2>/dev/null && echo "  ✔ Old journal logs cleaned"

echo -e "\n[5/8] Trash..."
rm -rf ~/.local/share/Trash/* 2>/dev/null && echo "  ✔ Trash cleaned"

echo -e "\n[6/8] Browser cache..."
rm -rf ~/.cache/brave-browser/* 2>/dev/null && echo "  ✔ Brave cache cleaned"

echo -e "\n[7/8] History + ZSH cache + npm..."
> ~/.bash_history 2>/dev/null && echo "  ✔ bash history cleared"
rm -f ~/.zcompdump* 2>/dev/null && echo "  ✔ ZSH compdump cache cleared"
rm -rf ~/.npm/* 2>/dev/null && echo "  ✔ npm cache cleared"
rm -rf ~/.cache/thumbnails/* 2>/dev/null && echo "  ✔ Thumbnail cache cleaned"

echo -e "\n[8/8] Flatpak unused runtimes..."
flatpak uninstall --unused -y 2>/dev/null && echo "  ✔ Unused flatpak removed"

echo -e "\n========================================="
echo "           CLEANUP COMPLETE"
echo "========================================="