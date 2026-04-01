# Field Toolkit Pro (FS25)

An advanced, highly optimized field creation and maintenance toolkit for the GIANTS Editor 10 (Farming Simulator 25). 

This script is designed to drastically speed up the workflow for map makers, especially when dealing with complex, organic field shapes, internal exclusion zones (like water ditches, erosion gullies, or grass strips), and spline-based field generation.

## 🤝 Community & Support
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
* **FS25 Ground States UI**: Fully updated for FS25! Choose from all 15 terrain detail states (Stubble Tillage, Seedbed, Plowed, Sown, etc.) using a native pop-up dialog, or use the quick-action button for standard cultivation.
* **Dynamic Farmland Detection**: The 'Rename Fields' tool now calculates the field's true geometric center on the fly to safely read the Farmland ID, making it completely independent of manually moved indicators.
* **Auto-Centering**: Field indicators and teleport nodes are automatically centered using a mathematical bounding box the exact second a field is generated, ignoring uneven point distributions.
* **AI Helper Validation**: Prevents game crashes by strictly checking both main fields AND exclusion zones for duplicate vertices.
* **Visual Debugging**: Renders field boundaries and exclusion zones (in orange) directly in the GE viewport.

## 📥 Installation
1. Download the `fieldToolkitPro.lua` file.
2. Place it in your custom GE scripts folder (usually `Win+R` -> `%localappdata%\GIANTS Editor 64bit 10.0.11\scripts\`).
3. Run it via the GIANTS Editor script menu.

## 🛠️ How to Use

### 1. Field Creation
* **Create Field (Points)**: Moves the camera to your desired location, creates a `fieldXXX` group at the origin `(0,0,0)`, places the first polygon point right in front of your camera, and auto-centers the indicator.
* **Create Field (from Spline)**: Draw a spline in GE (`Create -> Spline`), select it, and click this button to automatically generate a full field from the curve.

### 2. Field Exclusions (Holes)
* **Add Exclusion (Points)**: Select a `fieldXXX` group. The script creates the necessary sub-folders (`exclusion1`, `exclusion2`, etc.) and spawns a starting point in front of your camera.
* **Add Exclusion (from Spline)**: Draw a spline for your ditch/hole. Select BOTH the `fieldXXX` group AND the spline (using `CTRL + Click`). The script will convert the spline into a perfectly aligned exclusion zone.

### 3. Field Maintenance & Painting
* **Paint Field (Default)**: 1-click quick action to paint the field with the standard 'Cultivated' state. Automatically punches out all exclusion zones back to grass.
* **Repaint (Custom State)**: Opens a list dialog to select any of the 15 FS25 ground states to paint your field with.
* **Rename Fields**: Automatically renames your fields (e.g., `field01`) to match their underlying Farmland ID. Uses a dynamic on-the-fly bounding box calculation to ensure 100% accuracy.
* **Center Indicators (Bounding Box)**: Manually recalculates and places the field's name and teleport indicators in the exact visual center of the field, ensuring the icon never ends up outside your field. (except complete crazy field shapes)

### 4. Sizes & Notes
* **Update Field Sizes**: Calculates the exact hectare size of your fields (accurately subtracting all exclusion zones) and updates the internal floating 3D notes.

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