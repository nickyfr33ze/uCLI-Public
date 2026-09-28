echo "[*] Running updates..."
sleep 0.5
echo "[*] Running: 'sudo apt update'"
sleep 0.5
echo "[!] If you are not 'root' please input your password."
sudo apt update
sleep 0.5
echo "------------------------"
sleep 0.5
echo "[*] Updates complete."
sleep 0.5
echo "------------------------"
sleep 0.5
echo "[*] Running: sudo apt upgrade -f -y"
sleep 0.5
echo "-----------------------------------"
sudo apt upgrade -f -y
sleep 0.5
echo "------------------------"
echo "[*] Upgrades complete."
sleep 0.5
echo "------------------------"
sleep 0.5
echo "[*] Running: 'sudo apt autoremove -y'"
sudo apt autoremove -y
sleep 0.5
echo "--------------------------------------------"
sleep 0.5
echo "[*] Applications autoremoved successfully."
sleep 0.5
echo "--------------------------------------------"
sleep 0.5
echo "[!] UPDATES AND UPGRADE APPLIED. "
sleep 1
echo "--------------------------------------------"
sleep 0.5
echo "[*] Running: 'sudo apt clean'"
sudo apt clean
sleep 0.5
echo "[*] Running: 'sudo apt autoclean'"
sudo apt autoclean
echo "--------------------------------------------"
sleep 0.5
echo "[!] CLEANING COMPLETE."
sleep 0.5
echo "============================================"
sleep 0.5
echo "[!] TERMINATING PROGRAM. GOODBYE :)"
sleep 0.5
echo "==========================================="
sleep 0.5
