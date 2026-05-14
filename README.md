# MyCropResize

A focused iOS tool for resizing and cropping screenshots for App Store Connect submissions.

## Overview

MyCropResize is built for iOS developers who need to quickly prepare screenshots for App Store Connect. It handles the repetitive work of cropping and resizing screen captures to the exact pixel dimensions required by Apple.

## Features

- **Image selection** — Pick any image from your photo library
- **Crop** — Draw a crop region interactively with optional aspect ratio lock (Free / 1:1 / 4:3 / 16:9 / 9:16 / App Store)
- **Resize** — Enter exact pixel dimensions (Width × Height)
- **Keep Aspect Ratio** — Toggle to auto-calculate the opposite dimension when you change one
- **Preset sizes** — One-tap presets for the most common App Store screenshot sizes:
  - iPhone 6.7" — 1290 × 2796
  - iPhone 6.5" — 1242 × 2688
  - iPhone 5.5" — 1242 × 2208
  - iPad 13" — 2064 × 2752
  - iPad 12.9" — 2048 × 2732
- **Save** — Export as PNG (lossless) or JPEG directly to the Photos library
- **Reset** — Clear processing and start over with the original image

## Requirements

- Xcode 16 or later
- iOS 17 or later deployment target
- Swift 5.9+

## Running the App

1. Open `MyCropResize.xcodeproj` in Xcode
2. Select your target device or simulator
3. Press **⌘R** to build and run

On first launch, the app will request Photos library access when you save a processed image.

## Intended Use

This app is not a general photo editor. It is specifically designed for the workflow of:

1. Taking a simulator or device screenshot
2. Cropping out status bars, home indicators, or unwanted content
3. Scaling the result to an exact App Store Connect–required resolution
4. Saving the final PNG or JPEG ready for upload
