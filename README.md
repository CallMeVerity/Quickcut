# E-Z Cut

Lightweight video cutter powered by ffmpeg.

<img width="2548" height="1386" alt="image" src="https://github.com/user-attachments/assets/5b3d1b2a-8509-4cf8-a86e-8b3b997ef5fc" />

## Installation

### Arch Linux

Install from the AUR:

```bash
yay -S ezcut
```

### Build from Source

```bash
sudo pacman -S ffmpeg qt6-base qt6-declarative qt6-multimedia cmake ninja

git clone https://github.com/e-z-services/e-z-cut.git
cd e-z-cut

cmake --preset linux-release
cmake --build --preset linux-release

./build/linux-release/ezcut
```

To install system-wide:

```bash
sudo cmake --install build/linux-release
```

## License

MIT License
