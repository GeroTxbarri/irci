#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "=== Ensamblando snake.rtm ==="
qemu-x86_64 ./rtm32.asm-1.2.0/x86_64-linux-musl-rtm32.asm snake.rtm -o snake.bin
echo "Ensamblado exitoso: snake.bin"

# Asegurar el shim para capturar el PTY de la UART
mkdir -p "$DIR/bin"
cat << 'EOF' > "$DIR/bin/xterm"
#!/usr/bin/env bash
echo "$4" > /tmp/rtm32_pty.txt
EOF
chmod +x "$DIR/bin/xterm"

rm -f /tmp/rtm32_pty.txt

cleanup() {
    if [ -n "$EMU_PID" ]; then
        kill "$EMU_PID" 2>/dev/null || true
        wait "$EMU_PID" 2>/dev/null || true
    fi
    rm -f /tmp/rtm32_pty.txt
    echo -e "\n=== RTM32 detenido ==="
}
trap cleanup EXIT INT TERM

echo "=== Iniciando emulador RTM32 ==="
PATH="$DIR/bin:$PATH" qemu-x86_64 ./rtm32 -d telnet > /dev/null 2>&1 &
EMU_PID=$!

# Esperar a que el emulador cree la UART
for i in {1..30}; do
    if [ -f /tmp/rtm32_pty.txt ]; then break; fi
    sleep 0.1
done

if [ ! -f /tmp/rtm32_pty.txt ]; then
    echo "Error: No se pudo inicializar la UART de RTM32"
    exit 1
fi

PTY=$(cat /tmp/rtm32_pty.txt)

# Cargar el binario y poner en marcha el procesador vía debugger telnet
(
  sleep 0.4
  echo "load snake.bin"
  sleep 0.2
  echo "c"
) | telnet -4 localhost 4444 > /dev/null 2>&1 &

echo "=== Conectando consola visual (Presiona Ctrl+C para salir) ==="
sleep 0.5
picocom -q "$PTY"
