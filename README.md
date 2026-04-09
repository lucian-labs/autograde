# autograde

Fast drag-drop photo and video grading for macOS. Drop files, auto-apply exposure + film grain + watermark, export. Replaces the Lightroom export loop for personal use.

## What it does

- Drag images and videos from Finder or a memory card directly onto the window
- Auto mode applies: exposure lift, film grain, branded watermark
- Per-card sliders for exposure, grain, contrast, saturation
- Before/after toggle per card (hold Option)
- Batch export to a chosen folder as high-quality JPEG / MOV

## Stack

SwiftUI + Core Image + AVFoundation. macOS 14+.

## Build

```
xcodegen generate
open autograde.xcodeproj
```
