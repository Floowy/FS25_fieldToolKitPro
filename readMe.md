# Field Toolkit Pro (FS25)

An advanced, highly optimized field creation and maintenance toolkit for the GIANTS Editor 10 (Farming Simulator 25). 

This script is designed to drastically speed up the workflow for map makers, especially when dealing with complex, organic field shapes, internal exclusion zones (like water ditches, erosion gullies, or grass strips), and spline-based field generation.

## 💬 Community & Support
Join our community on Discord for support, feedback, and more modding discussions:
[Deutsch-Schweizer Agrarservice Discord](https://discord.gg/deutsch-schweizer-agrarservice-676093800057143325)

## 🌟 Acknowledgements & Credits
This toolkit is not entirely built from scratch but is a heavily expanded and combined evolution of two fantastic community resources:
* **mleithner (GIANTS Software)**: The original author of the baseline `Field Toolkit`, which provided the core logic for field creation, validation, and ground repainting.
* **W_R (FarmerBoysModding)**: The original author of the `Field Islands Splines` concept, which provided the genius idea of converting GIANTS Editor splines into terrain-aligned polygon points.

We merged these concepts, completely rewrote the UI, added robust bounding-box centering, duplicate-vertex validation for AI helpers, and introduced a smart, non-destructive "Exclusion Zone" system to keep your scenegraph perfectly clean.

## ✨ Features
* **Spline-to-Field Generation**: Draw a spline in the GE, click a button, and generate a perfect, ground-aligned field boundary.
* **Smart Exclusion Zones (Holes)**: Easily punch holes into your fields for grass strips or ditches. Exclusions are only created "on demand" to keep your scenegraph clean.
* **Exclusions via Spline**: Draw a spline inside your field, and the script converts it into an exclusion zone, automatically punching it out of the `terrainDetail` layer when repainting.
* **Bounding-Box Centering**: Field indicators and teleport nodes are perfectly centered based on the mathematical bounding box of your field, ignoring uneven point distributions.
* **AI Helper Validation**: Prevents game crashes by strictly checking both main fields AND exclusion zones for duplicate vertices.
* **Visual Debugging**: Renders field boundaries and exclusion zones (in orange) directly in the GE viewport.

## 🚀 Installation
1. Download the `fieldToolkitPro.lua` file.
2. Place it in your GIANTS Editor scripts folder (usually `C:\Program Files\GIANTS Software\GIANTS Editor 10.0.11\scripts\`).
3. Alternatively, place it in your editor's custom script folder (usually Win+R %localappdata%\GIANTS Editor 64bit 10.0.11\scripts\ ) and run it via the GE script menu. (<-- recommended)

## 📖 How to Use

### 1. Field Creation
* **Create Field (Points)**: Moves the camera to your desired location, creates a `fieldXXX` group at the origin `(0,0,0)`, and places the first polygon point right in front of your camera.
* **Create Field (from Spline)**: Draw a spline in GE (`Create -> Spline`), select it, and click this button to automatically generate a full field from the curve.

### 2. Field Exclusions (Holes)
* **Add Exclusion (Points)**: Select a `fieldXXX` group. The script creates the necessary sub-folders (`exclusion1`, `exclusion2`, etc.) and spawns a starting point in front of your camera.
* **Add Exclusion (from Spline)**: Draw a spline for your ditch/hole. Select BOTH the `fieldXXX` group AND the spline (using `CTRL + Click`). The script will convert the spline into a perfectly aligned exclusion zone.

### 3. Painting
* **Paint Fields**: Paints the field boundaries and immediately subtracts all your created exclusion zones from the terrain detail layer automatically.

### 4. Field Maintenance & Utilities
* **Center Indicators (Bounding Box)**: Accurately places the field's name and teleport indicators in the exact visual center of the field. It uses a mathematical bounding box to completely ignore uneven point distributions (e.g., when a curved edge has 20 points but a straight edge only has 2), ensuring the icon never ends up outside your field.
* **Update Field Sizes**: Calculates the exact hectare size of your fields (including subtracted exclusions) and updates the internal notes.

## 📄 License
**MIT License**

Copyright (c) 2026 [DSA]Floowy & Modding Community

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.