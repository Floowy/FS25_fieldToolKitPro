-- Author: mleithner (Modified by Gemini & [DSA]Floowy)
-- Name: Field Toolkit Pro
-- Namespace: local
-- Description: Advanced Field Creation Toolkit with Exclusion Zones and Spline Support.
-- Icon:
-- Hide: no
-- AlwaysLoaded: no

source("editorUtils.lua")
local gamePath = EditorUtils.getGameBasePath()
if gamePath == nil then
    return
end

source("map/farmlandFields/fieldUtil.lua")
source("ui/MessageBox.lua")
source(gamePath .. "dataS/scripts/shared/class.lua")
source(gamePath .. "dataS/scripts/utils/MathUtil.lua")
source(gamePath .. "dataS/scripts/utils/Utils.lua")
source(gamePath .. "dataS/scripts/densityMaps/InfoLayer.lua")

FieldToolkit = {}
FieldToolkit.WINDOW_WIDTH = 640
FieldToolkit.WINDOW_HEIGHT = -1
FieldToolkit.TEXT_WIDTH = 230
FieldToolkit.TEXT_HEIGHT = -1

function FieldToolkit.new()
    local self = setmetatable({}, {__index=FieldToolkit})

    self.window = nil
    if g_currentFieldToolkitDialog ~= nil then
        g_currentFieldToolkitDialog:close()
    end

    self:_initializeHelpTexts()
    self:generateUI()

    g_currentFieldToolkitDialog = self
    return self
end

-- ==================================================================
-- HELP TEXT DEFINITIONS
-- ==================================================================
function FieldToolkit:_initializeHelpTexts()
    self.helpTexts = {}

    self.helpTexts.createField = [[HOW TO: Create Field
-- METHOD 1: POINTS (Camera) --
1. Move camera to the desired start location and click 'Points (Camera)'.
2. A new 'fieldXXX' is created. Duplicate 'point1' (CTRL+D) and place around the boundary.

-- METHOD 2: FROM SPLINE --
1. Draw a spline in GE (Create -> Spline) representing the boundary.
2. Select the spline in the Scenegraph and click 'From Spline'.
3. The script auto-generates the field with terrain-aligned points.]]

    self.helpTexts.addExcl = [[HOW TO: Add Exclusion (Holes/Ditches)
-- METHOD 1: POINTS (Camera) --
1. Select the main 'fieldXXX' group and click 'Points (Camera)'.
2. An 'exclusionX' group is added. Duplicate 'point1' to outline the hole.
* Click again on the same field to sequentially add exclusion2, exclusion3, etc.

-- METHOD 2: FROM SPLINE --
1. Draw a spline outlining the hole.
2. Select BOTH the 'fieldXXX' AND the drawn spline (CTRL + Click).
3. Click 'From Spline' to auto-generate the exclusion points.
* Works sequentially too! Each new spline selected adds the next exclusion number.]]

    self.helpTexts.repaint = [[HOW TO: Repaint Fields
Paints the cultivated ground state to the terrainDetail layer and perfectly punches out any 'exclusionX' zones.]]

    self.helpTexts.repaintFarmland = [[HOW TO: Repaint to Farmland
Automatically paints the field's exact boundary shape into the 'farmlands' InfoLayer.
The script assigns the Farmland ID based on the field's sequential order in the scenegraph.]]

    self.helpTexts.clearGround = [[HOW TO: Clear Field Ground
Removes the terrainDetail layer (plowed/cultivated states) within the selected field or across the map.]]

    self.helpTexts.clearFruits = [[HOW TO: Clear Fruits
Removes grass and foliage layers within the field boundaries.]]

    self.helpTexts.center = [[HOW TO: Center Indicators
Calculates a geometric bounding box around the field boundaries and places the indicators exactly in the center, ignoring uneven point densities.]]

    self.helpTexts.alignPoints = [[HOW TO: Align Points to Terrain
Snaps all polygon points (including exclusions) perfectly to the terrain surface height.]]

    self.helpTexts.renamePoints = [[HOW TO: Rename Polygon Points
Renames points sequentially (point1, point2...) to clean up the scenegraph.]]

    self.helpTexts.renameFields = [[HOW TO: Rename Fields
Automatically renames fields (e.g., field01) to match their underlying farmland ID.]]

    self.helpTexts.convertOld = [[HOW TO: Convert Old Fields
Converts legacy FS19/FS22 field structures (with angle/dimension setups) to the modern FS25 polygon point format.]]

    self.helpTexts.validate = [[HOW TO: Validate Fields
Checks for critical errors like duplicate vertices or overlapping farmlands that could crash the game or AI helpers.]]

    self.helpTexts.updateSizes = [[HOW TO: Field Sizes
Calculates the exact hectare size (subtracting any exclusion zones) and updates the floating editor note.]]

    self.helpTexts.notes = [[HOW TO: Field Notes
Toggles the visibility of the field name and size indicators floating above the fields.]]

    self.helpTexts.debug = [[HOW TO: Render Viewport
Toggles visual boundaries in the editor. Fields render blue/pink, exclusions render orange. A red box warns of invalid shapes.]]
end

function FieldToolkit:showHelp(topic)
    if self.helpTexts[topic] then
        self.helpTextArea:setValue(self.helpTexts[topic])
        self.helpPanel:setVisible(true)
        self.window:fit()
    end
end

function FieldToolkit:hideHelp()
    self.helpPanel:setVisible(false)
    self.window:fit()
end

-- ==================================================================
-- USER INTERFACE
-- ==================================================================

function FieldToolkit:createToolRow(parentSizer, labelText, btn1Txt, btn1Fn, btn2Txt, btn2Fn, helpTopic)
    local rowSizer = UIColumnLayoutSizer.new()
    UIPanel.new(parentSizer, rowSizer, -1, -1, -1, -1, BorderDirection.BOTTOM, 2)

    UILabel.new(rowSizer, labelText, false, TextAlignment.LEFT, VerticalAlignment.TOP, -1, -1, 200, -1)

    if btn1Txt then UIButton.new(rowSizer, btn1Txt, btn1Fn, self, -1, -1, 130, -1) end
    if btn2Txt then UIButton.new(rowSizer, btn2Txt, btn2Fn, self, -1, -1, 130, -1, BorderDirection.LEFT, 5) end

    if helpTopic then
        UIButton.new(rowSizer, "(?)", function() self:showHelp(helpTopic) end, self, -1, -1, 30, -1, BorderDirection.LEFT, 5)
    end
end

function FieldToolkit:generateUI()
    local frameRowSizer = UIRowLayoutSizer.new()
    self.window = UIWindow.new(frameRowSizer, "Field Toolkit Pro")

    local borderSizer = UIRowLayoutSizer.new()
    UIPanel.new(frameRowSizer, borderSizer, -1, -1, -1, -1, BorderDirection.NONE, 0, 1)

    local mainStack = UIRowLayoutSizer.new()
    UIPanel.new(borderSizer, mainStack, -1, -1, FieldToolkit.WINDOW_WIDTH, FieldToolkit.WINDOW_HEIGHT, BorderDirection.ALL, 10, 1)

    -- ############ 1. FIELD CREATION ############
    local sec1Sizer = UIRowLayoutSizer.new()
    UIPanel.new(mainStack, sec1Sizer, -1, -1, -1, -1, BorderDirection.BOTTOM, 5)
    local title1 = UILabel.new(sec1Sizer, "1. Field Creation", false, TextAlignment.LEFT, VerticalAlignment.TOP, -1, -1, FieldToolkit.TEXT_WIDTH, FieldToolkit.TEXT_HEIGHT, BorderDirection.BOTTOM, 5)
    title1:setBold(true)

    self:createToolRow(sec1Sizer, "Create new Field:", "Points (Camera)", function() self:createField(false) end, "From Spline", function() self:createField(true) end, "createField")

    UIHorizontalLine.new(mainStack, -1, -1, -1, -1, BorderDirection.BOTTOM, 5)

    -- ############ 2. FIELD EXCLUSIONS ############
    local sec2Sizer = UIRowLayoutSizer.new()
    UIPanel.new(mainStack, sec2Sizer, -1, -1, -1, -1, BorderDirection.BOTTOM, 5)
    local title2 = UILabel.new(sec2Sizer, "2. Field Exclusions (Holes)", false, TextAlignment.LEFT, VerticalAlignment.TOP, -1, -1, FieldToolkit.TEXT_WIDTH, FieldToolkit.TEXT_HEIGHT, BorderDirection.BOTTOM, 5)
    title2:setBold(true)

    self:createToolRow(sec2Sizer, "Add Exclusion Hole:", "Points (Camera)", function() self:addExclusion(false) end, "From Spline", function() self:addExclusion(true) end, "addExcl")

    -- ############ HELP PANEL (Hidden by default) ############
    local helpPanelSizer = UIRowLayoutSizer.new()
    self.helpPanel = UIPanel.new(mainStack, helpPanelSizer, -1, -1, -1, -1, BorderDirection.ALL, 5)
    self.helpTextArea = UITextArea.new(helpPanelSizer, "", TextAlignment.LEFT, true, true, -1, -1, 600, 170)
    UIButton.new(helpPanelSizer, "Close Help", function() self:hideHelp() end, self, -1, -1, -1, 22, BorderDirection.TOP, 5)
    self.helpPanel:setVisible(false)

    UIHorizontalLine.new(mainStack, -1, -1, -1, -1, BorderDirection.BOTTOM, 5)

    -- ############ 3. FIELD MAINTENANCE ############
    local sec3Sizer = UIRowLayoutSizer.new()
    UIPanel.new(mainStack, sec3Sizer, -1, -1, -1, -1, BorderDirection.BOTTOM, 5)
    local title3 = UILabel.new(sec3Sizer, "3. Field Maintenance & Painting", false, TextAlignment.LEFT, VerticalAlignment.TOP, -1, -1, FieldToolkit.TEXT_WIDTH, FieldToolkit.TEXT_HEIGHT, BorderDirection.BOTTOM, 5)
    title3:setBold(true)

    self:createToolRow(sec3Sizer, "Repaint Fields", "Selected Field", function() self:repaintFields(getSelection(0)) end, "All Fields", function() self:repaintFields() end, "repaint")
    self:createToolRow(sec3Sizer, "Repaint to Farmland", "Selected Field", function() self:repaintFarmlandFields(getSelection(0)) end, "All Fields", function() self:repaintFarmlandFields() end, "repaintFarmland")
    self:createToolRow(sec3Sizer, "Clear Field Ground", "Selected Field", function() self:clearFieldGround(getSelection(0)) end, "Map", function() self:clearFieldGround() end, "clearGround")
    self:createToolRow(sec3Sizer, "Clear Fruits", "Selected Field", function() self:clearFruits(getSelection(0)) end, "All Fields", function() self:clearFruits() end, "clearFruits")
    self:createToolRow(sec3Sizer, "Center Indicators", "Selected Field", function() self:centerIndicators(getSelection(0)) end, "All Fields", function() self:centerIndicators() end, "center")
    self:createToolRow(sec3Sizer, "Align Points To Terrain", "Selected Field", function() self:alignPolygonPointsToTerrain(getSelection(0)) end, "All Fields", function() self:alignPolygonPointsToTerrain() end, "alignPoints")
    self:createToolRow(sec3Sizer, "Rename Polygon Points", "Selected Field", function() self:renamePolygonPoints(getSelection(0)) end, "All Fields", function() self:renamePolygonPoints() end, "renamePoints")
    self:createToolRow(sec3Sizer, "Rename Fields", "Selected Field", function() self:adjustFieldNames(getSelection(0)) end, "All Fields", function() self:adjustFieldNames() end, "renameFields")
    self:createToolRow(sec3Sizer, "Convert old", "Selected Field", function() self:convertOldField(getSelection(0)) end, "All Fields", function() self:convertOldField() end, "convertOld")
    self:createToolRow(sec3Sizer, "Validate Fields", "Selected Field", function() self:validateFields(getSelection(0)) end, "All Fields", function() self:validateFields() end, "validate")

    UIHorizontalLine.new(mainStack, -1, -1, -1, -1, BorderDirection.BOTTOM, 5)

    -- ############ 4. SIZES & NOTES ############
    local sec4Sizer = UIRowLayoutSizer.new()
    UIPanel.new(mainStack, sec4Sizer, -1, -1, -1, -1, BorderDirection.BOTTOM, 5)
    local title4 = UILabel.new(sec4Sizer, "4. Field Sizes & Notes", false, TextAlignment.LEFT, VerticalAlignment.TOP, -1, -1, FieldToolkit.TEXT_WIDTH, FieldToolkit.TEXT_HEIGHT, BorderDirection.BOTTOM, 5)
    title4:setBold(true)

    local sizeRow = UIColumnLayoutSizer.new(); UIPanel.new(sec4Sizer, sizeRow, -1, -1, -1, -1, BorderDirection.BOTTOM, 2)
    UILabel.new(sizeRow, "Field Size", false, TextAlignment.LEFT, VerticalAlignment.TOP, -1, -1, 200, -1)
    UIButton.new(sizeRow, "Get Total", function() self:calculateTotalSize() end, self, -1, -1, 85, -1)
    UIButton.new(sizeRow, "Update Field", function() self:updateFieldSizes(getSelection(0), false) end, self, -1, -1, 85, -1, BorderDirection.LEFT, 5)
    UIButton.new(sizeRow, "Update All", function() self:updateFieldSizes(nil, true) end, self, -1, -1, 85, -1, BorderDirection.LEFT, 5)
    UIButton.new(sizeRow, "(?)", function() self:showHelp("updateSizes") end, self, -1, -1, 30, -1, BorderDirection.LEFT, 5)

    local noteRow = UIColumnLayoutSizer.new(); UIPanel.new(sec4Sizer, noteRow, -1, -1, -1, -1, BorderDirection.BOTTOM, 2)
    UILabel.new(noteRow, "Field Notes", false, TextAlignment.LEFT, VerticalAlignment.TOP, -1, -1, 200, -1)
    UIButton.new(noteRow, "Toggle Visibility All", function() self:toggleNoteRendering() end, self, -1, -1, 265, -1)
    UIButton.new(noteRow, "(?)", function() self:showHelp("notes") end, self, -1, -1, 30, -1, BorderDirection.LEFT, 5)

    UIHorizontalLine.new(mainStack, -1, -1, -1, -1, BorderDirection.BOTTOM, 5)

    -- ############ 5. DEBUG ############
    local debugSizer = UIRowLayoutSizer.new()
    UIPanel.new(mainStack, debugSizer, -1, -1, -1, -1, BorderDirection.BOTTOM, 5)
    local envTitle = UILabel.new(debugSizer, "Debug", false, TextAlignment.LEFT, VerticalAlignment.TOP, -1, -1, FieldToolkit.TEXT_WIDTH, FieldToolkit.TEXT_HEIGHT, BorderDirection.BOTTOM, 5)
    envTitle:setBold(true)

    local dRow = UIColumnLayoutSizer.new(); UIPanel.new(debugSizer, dRow, -1, -1, -1, -1, BorderDirection.BOTTOM, 2)
    UILabel.new(dRow, "Render Viewport", false, TextAlignment.LEFT, VerticalAlignment.TOP, -1, -1, 200, -1)
    UIButton.new(dRow, "Toggle Debug Rendering", function() self:toggleDebugRendering() end, self, -1, -1, 265, -1)
    UIButton.new(dRow, "(?)", function() self:showHelp("debug") end, self, -1, -1, 30, -1, BorderDirection.LEFT, 5)

    self.window:setOnCloseCallback(function() self:onClose() end)
    self.window:showWindow()
end

function FieldToolkit:close()
    self.window:close()
end

function FieldToolkit:onClose()
    self:deactivateDebugRendering()
end

-- ==================================================================
-- CORE LOGIC METHODS
-- ==================================================================

function FieldToolkit:_splineToPoints(splineNode, parentNode, terrainNode)
    if not getHasClassId(splineNode, ClassIds.SHAPE) or not getHasClassId(getGeometry(splineNode), ClassIds.SPLINE) then
        return false
    end

    for j = 0, getSplineNumOfCV(splineNode) - 1 do
        local wx, wy, wz = getSplineCV(splineNode, j)
        local ty = getTerrainHeightAtWorldPos(terrainNode, wx, wy, wz)
        local pointTG = createTransformGroup("point" .. tostring(j + 1))
        link(parentNode, pointTG)
        setWorldTranslation(pointTG, wx, ty, wz)
    end

    return true
end

function FieldToolkit:_generateBaseFieldStructure(fieldNode, newFieldName, spawnX, spawnY, spawnZ)
    local field = createTransformGroup(newFieldName)
    link(fieldNode, field)

    local polygonPoints = createTransformGroup("polygonPoints")
    local nameIndicator = createTransformGroup("nameIndicator")
    local teleportIndicator = createTransformGroup("teleportIndicator")

    local note = createNoteNode(nameIndicator, newFieldName, 0, 0, 0, true)
    link(nameIndicator, note)

    setWorldTranslation(nameIndicator, spawnX, spawnY, spawnZ)
    setWorldTranslation(teleportIndicator, spawnX, spawnY, spawnZ)

    link(field, polygonPoints)
    link(field, nameIndicator)
    link(field, teleportIndicator)

    setUserAttribute(field, "polygonIndex", UserAttributeType.STRING, EditorUtils.getNodeIndexPath(field, polygonPoints))
    setUserAttribute(field, "nameIndicatorIndex", UserAttributeType.STRING, EditorUtils.getNodeIndexPath(field, nameIndicator))
    setUserAttribute(field, "teleportIndicatorIndex", UserAttributeType.STRING, EditorUtils.getNodeIndexPath(field, teleportIndicator))
    setUserAttribute(field, "angle", UserAttributeType.INTEGER, 0)
    setUserAttribute(field, "missionOnlyGrass", UserAttributeType.BOOLEAN, false)
    setUserAttribute(field, "missionAllowed", UserAttributeType.BOOLEAN, true)

    return field, polygonPoints
end

function FieldToolkit:createField(fromSpline)
    local fieldNode = FieldUtil.getFieldsRootNode()
    if fieldNode == nil then
        printError("No fields node defined")
        return nil
    end

    local terrainNode = EditorUtils.getIdsByName("terrain")[1]
    if terrainNode == nil then
        printError("No terrain defined!")
        return nil
    end

    local name = string.format("field%01d", getNumOfChildren(fieldNode) + 1)
    local spawnX, spawnY, spawnZ = 0, 0, 0
    local splineNode = nil

    if fromSpline then
        splineNode = getSelection(0)
        if splineNode == 0 or not getHasClassId(splineNode, ClassIds.SHAPE) or not getHasClassId(getGeometry(splineNode), ClassIds.SPLINE) then
            MessageBox.show("Error", "Please select a valid Spline to create the field from.")
            return nil
        end
        local wx, wy, wz = getSplineCV(splineNode, 0)
        spawnX = wx
        spawnZ = wz
        spawnY = getTerrainHeightAtWorldPos(terrainNode, spawnX, 0, spawnZ)
    else
        local cam = getCamera(0)
        if cam ~= 0 then
            local cx, cy, cz = getWorldTranslation(cam)
            local dx, dy, dz = localDirectionToWorld(cam, 0, 0, -1)
            local distance = 30
            spawnX = cx + (dx * distance)
            spawnZ = cz + (dz * distance)
            spawnY = getTerrainHeightAtWorldPos(terrainNode, spawnX, 0, spawnZ)
        end
    end

    local field, polygonPoints = self:_generateBaseFieldStructure(fieldNode, name, spawnX, spawnY, spawnZ)

    if fromSpline then
        self:_splineToPoints(splineNode, polygonPoints, terrainNode)
        print(string.format("Created new field '%s' from Spline.", name))
    else
        local point1 = createTransformGroup("point1")
        setWorldTranslation(point1, spawnX, spawnY, spawnZ)
        link(polygonPoints, point1)
        print(string.format("Created new field '%s' at camera focus.", name))
    end

    FieldToolkit.updateFieldNote(field)

    -- Auto-center indicators right after creation!
    -- For splines, it instantly finds the true center.
    -- For points, it safely targets the single initial point.
    self:centerIndicators(field)

    addSelection(field)
    return field
end

function FieldToolkit:addExclusion(fromSpline)
    local terrainNode = EditorUtils.getIdsByName("terrain")[1]
    if terrainNode == nil then return end

    local field = nil
    local splineNode = nil

    if fromSpline then
        for i = 0, getNumSelected() - 1 do
            local sel = getSelection(i)
            if getName(sel):match("^field") then
                field = sel
            elseif getHasClassId(sel, ClassIds.SHAPE) and getHasClassId(getGeometry(sel), ClassIds.SPLINE) then
                splineNode = sel
            end
        end
        if field == nil or splineNode == nil then
            MessageBox.show("Error", "Please select BOTH a 'fieldXXX' and a Spline (CTRL + Click).")
            return
        end
    else
        field = self:getFieldRootByNode(getSelection(0))
        if field == nil then
            MessageBox.show("Error", "Please select a 'fieldXXX' to add an exclusion to.")
            return
        end
    end

    local exclusionIndexPath = getUserAttribute(field, "exclusionIndex")
    local exclusionPointsRoot = nil

    if exclusionIndexPath ~= nil then
        exclusionPointsRoot = EditorUtils.getNodeByIndexPath(exclusionIndexPath, field)
    end

    if exclusionPointsRoot == nil then
        exclusionPointsRoot = createTransformGroup("exclusionPoints")
        link(field, exclusionPointsRoot)
        setUserAttribute(field, "exclusionIndex", UserAttributeType.STRING, EditorUtils.getNodeIndexPath(field, exclusionPointsRoot))
    end

    local nextId = 1
    for i = 0, getNumOfChildren(exclusionPointsRoot) - 1 do
        local child = getChildAt(exclusionPointsRoot, i)
        local num = tonumber(getName(child):match("^exclusion(%d+)"))
        if num and num >= nextId then
            nextId = num + 1
        end
    end

    local newExclName = "exclusion" .. nextId
    local newExclGroup = createTransformGroup(newExclName)
    link(exclusionPointsRoot, newExclGroup)

    if fromSpline then
        self:_splineToPoints(splineNode, newExclGroup, terrainNode)
        print(string.format("Added '%s' to '%s' from Spline.", newExclName, getName(field)))
        addSelection(newExclGroup)
    else
        local cam = getCamera(0)
        local spawnX, spawnY, spawnZ = 0, 0, 0
        if cam ~= 0 then
            local cx, cy, cz = getWorldTranslation(cam)
            local dx, dy, dz = localDirectionToWorld(cam, 0, 0, -1)
            spawnX = cx + (dx * 20)
            spawnZ = cz + (dz * 20)
            spawnY = getTerrainHeightAtWorldPos(terrainNode, spawnX, 0, spawnZ)
        end
        local point1 = createTransformGroup("point1")
        setWorldTranslation(point1, spawnX, spawnY, spawnZ)
        link(newExclGroup, point1)
        print(string.format("Added empty '%s' to '%s' at camera focus.", newExclName, getName(field)))
        addSelection(point1)
    end
end

-- ==================================================================
-- FIELD MAINTENANCE & UTILITY METHODS
-- ==================================================================

function FieldToolkit:worldPosToLocalInfoLayerPos(infoLayer, terrainSize, x, z)
    local width, height = getBitVectorMapSize(infoLayer)
    return math.floor(width * (x+terrainSize*0.5) / terrainSize),
           math.floor(height * (z+terrainSize*0.5) / terrainSize)
end

function FieldToolkit:adjustFieldNames(selectedNode)
    local fieldNode = FieldUtil.getFieldsRootNode()
    if fieldNode == nil then
        printError("No fields node defined")
        return
    end

    local terrainNode = EditorUtils.getIdsByName("terrain")[1]
    if terrainNode == nil then
        printError("No terrain defined!")
        return
    end

    local infoLayer = getInfoLayerFromTerrain(terrainNode, "farmlands")
    if infoLayer == nil or infoLayer == 0 then
        print("    Could not find farmlands info layer")
        return
    end

    local terrainSize = getTerrainSize(terrainNode)
    local numChannels = getBitVectorMapNumChannels(infoLayer)
    local selectedField = self:getFieldRootByNode(selectedNode)

    local fields = {}

    for i=0, getNumOfChildren(fieldNode)-1 do
        local field = getChildAt(fieldNode, i)
        if selectedField == nil or selectedField == field then
            local oldName = getName(field)

            local x, z = 0, 0
            local polyPath = getUserAttribute(field, "polygonIndex")
            local polygonNode = nil
            if polyPath ~= nil then
                polygonNode = EditorUtils.getNodeByIndexPath(polyPath, field)
            end

            -- FIX: Calculate the geometric center of the field on the fly to get a safe inside point
            if polygonNode ~= nil and getNumOfChildren(polygonNode) > 0 then
                local numPoints = getNumOfChildren(polygonNode)
                local minX, minZ = math.huge, math.huge
                local maxX, maxZ = -math.huge, -math.huge

                for j=0, numPoints-1 do
                    local point = getChildAt(polygonNode, j)
                    local px, _, pz = getWorldTranslation(point)
                    if px < minX then minX = px end
                    if px > maxX then maxX = px end
                    if pz < minZ then minZ = pz end
                    if pz > maxZ then maxZ = pz end
                end

                -- Use the exact center of the bounding box
                x = minX + ((maxX - minX) * 0.5)
                z = minZ + ((maxZ - minZ) * 0.5)
            end

            local lx, lz = self:worldPosToLocalInfoLayerPos(infoLayer, terrainSize, x, z)
            local farmlandId = getBitVectorMapPoint(infoLayer, lx, lz, 0, numChannels)

            local name = string.format("field%02d", farmlandId)

            if oldName ~= name then
                setName(field, name)
                print(string.format("    Adjusted field name from '%s' to '%s'", oldName, name))
            end

            FieldToolkit.updateFieldNote(field)

            if selectedField == nil then
                table.insert(fields, {node=field, name=name})
            end
        end
    end

    if #fields > 0 then
        table.sort(fields, function(a, b)
            return a.name < b.name
        end)

        for k, field in ipairs(fields) do
            link(fieldNode, field.node, k-1)
        end
    end

    print("Adjusted field names")
end

function FieldToolkit:clearFruits(selectedNode)
    local fieldNode = FieldUtil.getFieldsRootNode()
    if fieldNode == nil then return end
    local terrainNode = EditorUtils.getIdsByName("terrain")[1]
    if terrainNode == nil then return end

    local grass = getTerrainDataPlaneByName(terrainNode, "grass")
    if grass == 0 or grass == nil then
        printError("No grass foliage layer found")
        return
    end

    local selectedField = self:getFieldRootByNode(selectedNode)
    local modifier = DensityMapModifier.new(grass, 0, 3, terrainNode)
    modifier:clearPolygonPoints()
    modifier:setNewTypeIndexMode(DensityIndexCompareMode.ZERO)

    for i=0, getNumOfChildren(fieldNode)-1 do
        local field = getChildAt(fieldNode, i)
        if selectedField == nil or selectedField == field then
            local indexPath = getUserAttribute(field, "polygonIndex")
            local polygon = EditorUtils.getNodeByIndexPath(indexPath, field)
            if polygon ~= nil then
                modifier:clearPolygonPoints()
                for j=0, getNumOfChildren(polygon)-1 do
                    local polygonPoint = getChildAt(polygon, j)
                    local x, _, z = getWorldTranslation(polygonPoint)
                    modifier:addPolygonPointWorldCoords(x, z)
                end
                modifier:executeSet(0)
                print("    Cleared fruits on field '"..getName(field).."'")
            end
        end
    end
    print("Cleared field fruits")
end

function FieldToolkit:convertOldField(selectedNode)
    local fieldNode = FieldUtil.getFieldsRootNode()
    if fieldNode == nil then return end

    for i=0, getNumOfChildren(fieldNode)-1 do
        local field = getChildAt(fieldNode, i)
        if selectedNode == nil or selectedNode == field then
            local angle = getUserAttribute(field, "fieldAngle")
            local dimensionIndex = getUserAttribute(field, "fieldDimensionIndex")
            local nameIndicatorIndex = getUserAttribute(field, "nameIndicatorIndex")
            local fieldMissionAllowed = getUserAttribute(field, "fieldMissionAllowed")
            local fieldGrassMission = getUserAttribute(field, "fieldGrassMission")

            local isOld = angle ~= nil or dimensionIndex ~= nil or nameIndicatorIndex ~= nil or fieldMissionAllowed ~= nil or fieldGrassMission ~= nil

            if isOld then
                setName(field, getName(field) .. "_old")
                local newField = self:createField(false)

                angle = tonumber(angle)
                if angle ~= nil then setUserAttribute(newField, "angle", UserAttributeType.INTEGER, angle) end
                if fieldMissionAllowed then setUserAttribute(newField, "missionAllowed", UserAttributeType.BOOLEAN, true) end
                if fieldGrassMission then setUserAttribute(newField, "missionOnlyGrass", UserAttributeType.BOOLEAN, true) end

                if nameIndicatorIndex ~= nil then
                    local oldNameIndicatorNode = EditorUtils.getNodeByIndexPath(nameIndicatorIndex, field)
                    if oldNameIndicatorNode ~= nil then
                        local nameIndicatorNode = EditorUtils.getNodeByIndexPath(getUserAttribute(newField, "nameIndicatorIndex"), newField)
                        local teleportIndicatorNode = EditorUtils.getNodeByIndexPath(getUserAttribute(newField, "teleportIndicatorIndex"), newField)
                        local x, y, z = getWorldTranslation(oldNameIndicatorNode)
                        setWorldTranslation(nameIndicatorNode, x, y, z)
                        setWorldTranslation(teleportIndicatorNode, x, y, z)
                    end
                end

                if dimensionIndex ~= nil then
                    local oldDimensionNode = EditorUtils.getNodeByIndexPath(dimensionIndex, field)
                    if oldDimensionNode ~= nil then
                        local polygonNode = EditorUtils.getNodeByIndexPath(getUserAttribute(newField, "polygonIndex"), newField)

                        local function copyOrCreatePolygonPoint(node, index)
                            local polygonPoint
                            if index > getNumOfChildren(polygonNode)-1 then
                                polygonPoint = createTransformGroup("point" .. index)
                                link(polygonNode, polygonPoint)
                            else
                                polygonPoint = getChildAt(polygonNode, index)
                            end
                            local x, y, z = getWorldTranslation(node)
                            setWorldTranslation(polygonPoint, x, y, z)
                        end

                        local index = 0
                        for i=0, getNumOfChildren(oldDimensionNode)-1 do
                            local p1 = getChildAt(oldDimensionNode, i)
                            copyOrCreatePolygonPoint(p1, index)
                            index = index + 1

                            local p2 = getChildAt(p1, 0)
                            copyOrCreatePolygonPoint(p2, index)
                            index = index + 1

                            local p3 = getChildAt(p1, 1)
                            copyOrCreatePolygonPoint(p3, index)
                            index = index + 1

                            local p4 = createTransformGroup("p4")
                            link(p1, p4)

                            local x1, y, z1 = getWorldTranslation(p1)
                            local x2, _, z2 = getWorldTranslation(p2)
                            local x3, _, z3 = getWorldTranslation(p3)

                            local dirX = x3 - x2
                            local dirZ = z3 - z2
                            setWorldTranslation(p4, x1 + dirX, y, z1 + dirZ)

                            copyOrCreatePolygonPoint(p4, index)
                            index = index + 1
                        end
                    end
                end
                FieldToolkit.updateFieldNote(newField)
                print("Converted old field structure to new polygon format.")
            end
        end
    end
end

function FieldToolkit:repaintFields(selectedNode)
    local fieldNode = FieldUtil.getFieldsRootNode()
    if fieldNode == nil then return end
    local terrainNode = EditorUtils.getIdsByName("terrain")[1]
    if terrainNode == nil then return end

    local selectedField = self:getFieldRootByNode(selectedNode)
    local terrainDetail, _ = getTerrainDataPlaneByName(terrainNode, "terrainDetail")
    local modifier = DensityMapModifier.new(terrainDetail, 0, 4, terrainNode)

    for i=0, getNumOfChildren(fieldNode)-1 do
        local field = getChildAt(fieldNode, i)
        if selectedField == nil or selectedField == field then
            local indexPath = getUserAttribute(field, "polygonIndex")
            local polygon = EditorUtils.getNodeByIndexPath(indexPath, field)

            if polygon ~= nil then
                modifier:clearPolygonPoints()
                for j=0, getNumOfChildren(polygon)-1 do
                    local polygonPoint = getChildAt(polygon, j)
                    local x, _, z = getWorldTranslation(polygonPoint)
                    modifier:addPolygonPointWorldCoords(x, z)
                end

                modifier:executeSet(2)
                print("    Repainted field '"..getName(field).."'")

                local exclusionIndexPath = getUserAttribute(field, "exclusionIndex")
                if exclusionIndexPath ~= nil then
                    local exclusionPointsRoot = EditorUtils.getNodeByIndexPath(exclusionIndexPath, field)
                    if exclusionPointsRoot ~= nil then
                        for e=0, getNumOfChildren(exclusionPointsRoot)-1 do
                            local exclusionPoly = getChildAt(exclusionPointsRoot, e)
                            if getNumOfChildren(exclusionPoly) >= 3 then
                                modifier:clearPolygonPoints()
                                for k=0, getNumOfChildren(exclusionPoly)-1 do
                                    local excPoint = getChildAt(exclusionPoly, k)
                                    local ex, _, ez = getWorldTranslation(excPoint)
                                    modifier:addPolygonPointWorldCoords(ex, ez)
                                end
                                modifier:executeSet(0)
                                print("      -> Punched exclusion zone '"..getName(exclusionPoly).."' in field '"..getName(field).."'")
                            end
                        end
                    end
                end
            end
        end
        FieldToolkit.updateFieldNote(field)
    end
    print("Repainted fields")
end

function FieldToolkit:alignPolygonPointsToTerrain(selectedNode)
    local fieldNode = FieldUtil.getFieldsRootNode()
    if fieldNode == nil then return end
    local terrainNode = EditorUtils.getIdsByName("terrain")[1]
    if terrainNode == nil then return end

    local selectedField = self:getFieldRootByNode(selectedNode)

    for i=0, getNumOfChildren(fieldNode)-1 do
        local field = getChildAt(fieldNode, i)
        if selectedField == nil or selectedField == field then
            local indexPath = getUserAttribute(field, "polygonIndex")
            local polygon = EditorUtils.getNodeByIndexPath(indexPath, field)
            if polygon ~= nil then
                for j=0, getNumOfChildren(polygon)-1 do
                    local polygonPoint = getChildAt(polygon, j)
                    local x, y, z = getWorldTranslation(polygonPoint)
                    y = getTerrainHeightAtWorldPos(terrainNode, x, y, z)
                    setWorldTranslation(polygonPoint, x, y, z)
                end
            end

            local exclusionIndexPath = getUserAttribute(field, "exclusionIndex")
            if exclusionIndexPath ~= nil then
                local exclusionPointsRoot = EditorUtils.getNodeByIndexPath(exclusionIndexPath, field)
                if exclusionPointsRoot ~= nil then
                    for e=0, getNumOfChildren(exclusionPointsRoot)-1 do
                        local exclusionPoly = getChildAt(exclusionPointsRoot, e)
                        for k=0, getNumOfChildren(exclusionPoly)-1 do
                            local excPoint = getChildAt(exclusionPoly, k)
                            local ex, ey, ez = getWorldTranslation(excPoint)
                            ey = getTerrainHeightAtWorldPos(terrainNode, ex, ey, ez)
                            setWorldTranslation(excPoint, ex, ey, ez)
                        end
                    end
                end
            end
        end
        FieldToolkit.updateFieldNote(field)
    end
    print("Aligned all fields and exclusion polygon points")
end

function FieldToolkit:renamePolygonPoints(selectedNode)
    local fieldNode = FieldUtil.getFieldsRootNode()
    if fieldNode == nil then return end

    local selectedField = self:getFieldRootByNode(selectedNode)

    for i=0, getNumOfChildren(fieldNode)-1 do
        local field = getChildAt(fieldNode, i)
        if selectedField == nil or selectedField == field then
            local indexPath = getUserAttribute(field, "polygonIndex")
            local polygon = EditorUtils.getNodeByIndexPath(indexPath, field)
            if polygon ~= nil then
                for j=0, getNumOfChildren(polygon)-1 do
                    local polygonPoint = getChildAt(polygon, j)
                    setName(polygonPoint, string.format("point%d", j+1))
                end
            end

            local exclusionIndexPath = getUserAttribute(field, "exclusionIndex")
            if exclusionIndexPath ~= nil then
                local exclusionPointsRoot = EditorUtils.getNodeByIndexPath(exclusionIndexPath, field)
                if exclusionPointsRoot ~= nil then
                    for e=0, getNumOfChildren(exclusionPointsRoot)-1 do
                        local exclusionPoly = getChildAt(exclusionPointsRoot, e)
                        setName(exclusionPoly, string.format("exclusion%d", e+1))
                        for k=0, getNumOfChildren(exclusionPoly)-1 do
                            local excPoint = getChildAt(exclusionPoly, k)
                            setName(excPoint, string.format("point%d", k+1))
                        end
                    end
                end
            end
        end
    end
    print("Renamed fields polygon points")
end

function FieldToolkit:centerIndicators(selectedNode)
    local fieldNode = FieldUtil.getFieldsRootNode()
    if fieldNode == nil then return end
    local terrainNode = EditorUtils.getIdsByName("terrain")[1]
    if terrainNode == nil then return end

    local selectedField = self:getFieldRootByNode(selectedNode)

    for i=0, getNumOfChildren(fieldNode)-1 do
        local field = getChildAt(fieldNode, i)
        if selectedField == nil or selectedField == field then
            local indexPath = getUserAttribute(field, "polygonIndex")
            local polygon = EditorUtils.getNodeByIndexPath(indexPath, field)

            if polygon ~= nil and getNumOfChildren(polygon) > 0 then
                local numPoints = getNumOfChildren(polygon)
                local minX, minZ = math.huge, math.huge
                local maxX, maxZ = -math.huge, -math.huge

                for j=0, numPoints-1 do
                    local point = getChildAt(polygon, j)
                    local px, _, pz = getWorldTranslation(point)
                    if px < minX then minX = px end
                    if px > maxX then maxX = px end
                    if pz < minZ then minZ = pz end
                    if pz > maxZ then maxZ = pz end
                end

                local centerX = minX + ((maxX - minX) * 0.5)
                local centerZ = minZ + ((maxZ - minZ) * 0.5)
                local centerY = getTerrainHeightAtWorldPos(terrainNode, centerX, 0, centerZ)

                local nameIndPath = getUserAttribute(field, "nameIndicatorIndex")
                local tpIndPath = getUserAttribute(field, "teleportIndicatorIndex")
                local nameInd = EditorUtils.getNodeByIndexPath(nameIndPath, field)
                local tpInd = EditorUtils.getNodeByIndexPath(tpIndPath, field)

                if nameInd ~= nil then setWorldTranslation(nameInd, centerX, centerY, centerZ) end
                if tpInd ~= nil then setWorldTranslation(tpInd, centerX, centerY, centerZ) end
            end
        end
    end
    print("Finished centering field indicators")
end

function FieldToolkit:validateFields(selectedNode)
    local fieldNode = FieldUtil.getFieldsRootNode()
    if fieldNode == nil then return end
    local terrainNode = EditorUtils.getIdsByName("terrain")[1]
    if terrainNode == nil then return end

    local farmlandInfoLayer = getInfoLayerFromTerrain(terrainNode, "farmlands")
    if farmlandInfoLayer == nil or farmlandInfoLayer == 0 then return end

    local selectedField = self:getFieldRootByNode(selectedNode)
    local terrainSize = getTerrainSize(terrainNode)
    _G["g_currentMission"] = { terrainSize = terrainSize }

    print("Start Field Validation")

    local infoLayer = InfoLayer.new("farmlands")
    infoLayer:loadFromMemory(farmlandInfoLayer)

    local modifier = DensityMapModifier.new(farmlandInfoLayer, 0, infoLayer.numChannels, terrainNode)
    local filter = DensityMapFilter.new(modifier)
    local farmlandIdFieldMapping = {}

    for i=0, getNumOfChildren(fieldNode)-1 do
        local field = getChildAt(fieldNode, i)
        if selectedField == nil or selectedField == field then
            local isValid = true
            local indexPath = getUserAttribute(field, "polygonIndex")
            local polygon = EditorUtils.getNodeByIndexPath(indexPath, field)

            if polygon ~= nil then
                local polygonNumChildren = getNumOfChildren(polygon)
                if polygonNumChildren > 0 then
                    local firstPolygonPoint = getChildAt(polygon, 0)
                    local x, _, z = getWorldTranslation(firstPolygonPoint)
                    local farmlandId = infoLayer:getValueAtWorldPos(x, z)

                    if farmlandIdFieldMapping[farmlandId] ~= nil then
                        printError(string.format("    Error: There already exists field '%s' on farmland '%s'", farmlandIdFieldMapping[farmlandId], farmlandId))
                        isValid = false
                    end

                    filter:setValueCompareParams(DensityValueCompareType.NOTEQUAL, farmlandId)
                    modifier:clearPolygonPoints()

                    local lastX, lastY, lastZ
                    for j=0, polygonNumChildren-1 do
                        local polygonPoint = getChildAt(polygon, j)
                        local px, py, pz = getWorldTranslation(polygonPoint)

                        if MathUtil.equalEpsilon(lastX, px) and MathUtil.equalEpsilon(lastY, py) and MathUtil.equalEpsilon(lastZ, pz) then
                            local prevPoint = getChildAt(polygon, j-1)
                            printError(string.format("    Error: duplicate polygon vertex at %d %d %d (nodes %q and %q)", px, py, pz, getName(prevPoint), getName(polygonPoint)))
                        end
                        lastX, lastY, lastZ = px, py, pz
                        modifier:addPolygonPointWorldCoords(px, pz)
                    end

                    local _, numPixels, _ = modifier:executeGet(filter)
                    if numPixels > 0 then
                        local numFarmlands = (2 ^ infoLayer.numChannels)-1
                        for j=0, numFarmlands do
                            if j ~= farmlandId then
                                filter:setValueCompareParams(DensityValueCompareType.EQUAL, j)
                                local _, numPixelsI, _ = modifier:executeGet(filter)
                                if numPixelsI > 0 then
                                    printError(string.format("    Error: Field '%s' touches farmland '%d' with '%d' pixels", getName(field), j, numPixelsI))
                                    isValid = false
                                end
                            end
                        end
                    end

                    if isValid then farmlandIdFieldMapping[farmlandId] = i+1 end
                end
            end

            local exclusionIndexPath = getUserAttribute(field, "exclusionIndex")
            if exclusionIndexPath ~= nil then
                local exclusionPointsRoot = EditorUtils.getNodeByIndexPath(exclusionIndexPath, field)
                if exclusionPointsRoot ~= nil then
                    for e=0, getNumOfChildren(exclusionPointsRoot)-1 do
                        local exclusionPoly = getChildAt(exclusionPointsRoot, e)
                        local excLastX, excLastY, excLastZ
                        for k=0, getNumOfChildren(exclusionPoly)-1 do
                            local excPoint = getChildAt(exclusionPoly, k)
                            local ex, ey, ez = getWorldTranslation(excPoint)

                            if MathUtil.equalEpsilon(excLastX, ex) and MathUtil.equalEpsilon(excLastY, ey) and MathUtil.equalEpsilon(excLastZ, ez) then
                                local prevExcPoint = getChildAt(exclusionPoly, k-1)
                                printError(string.format("    Error: duplicate EXCLUSION vertex at %d %d %d (nodes %q and %q) in '%s'", ex, ey, ez, getName(prevExcPoint), getName(excPoint), getName(exclusionPoly)))
                            end
                            excLastX, excLastY, excLastZ = ex, ey, ez
                        end
                    end
                end
            end
        end
        FieldToolkit.updateFieldNote(field)
    end
    print("Finished Field Validation")
end

function FieldToolkit:repaintFarmlandFields(selectedNode)
    local fieldNode = FieldUtil.getFieldsRootNode()
    if fieldNode == nil then return end
    local terrainNode = EditorUtils.getIdsByName("terrain")[1]
    if terrainNode == nil then return end
    local infoLayer = getInfoLayerFromTerrain(terrainNode, "farmlands")
    if infoLayer == nil or infoLayer == 0 then return end

    local selectedField = self:getFieldRootByNode(selectedNode)
    local size = getBitVectorMapNumChannels(infoLayer)
    local modifier = DensityMapModifier.new(infoLayer, 0, size, terrainNode)

    for i=0, getNumOfChildren(fieldNode)-1 do
        local field = getChildAt(fieldNode, i)
        if selectedField == nil or selectedField == field then
            local indexPath = getUserAttribute(field, "polygonIndex")
            local polygon = EditorUtils.getNodeByIndexPath(indexPath, field)
            if polygon ~= nil then
                modifier:clearPolygonPoints()
                for j=0, getNumOfChildren(polygon)-1 do
                    local polygonPoint = getChildAt(polygon, j)
                    local x, _, z = getWorldTranslation(polygonPoint)
                    modifier:addPolygonPointWorldCoords(x, z)
                end
                modifier:executeSet(i + 1)
            end
        end
    end
    print("Repainted fields to farmlands")
end

function FieldToolkit:clearFieldGround(selectedNode)
    local terrainNode = EditorUtils.getIdsByName("terrain")[1]
    if terrainNode == nil then return end

    local selectedField = self:getFieldRootByNode(selectedNode)
    local terrainDetail, _ = getTerrainDataPlaneByName(terrainNode, "terrainDetail")
    local modifier = DensityMapModifier.new(terrainDetail, 0, 4, terrainNode)
    modifier:clearPolygonPoints()

    if selectedField ~= nil then
        local indexPath = getUserAttribute(selectedField, "polygonIndex")
        local polygon = EditorUtils.getNodeByIndexPath(indexPath, selectedField)
        if polygon ~= nil then
            for j=0, getNumOfChildren(polygon)-1 do
                local polygonPoint = getChildAt(polygon, j)
                local x, _, z = getWorldTranslation(polygonPoint)
                modifier:addPolygonPointWorldCoords(x, z)
            end
        end
    end
    modifier:executeSet(0)
    print("Cleared field ground")
end

function FieldToolkit:getFieldRootByNode(node)
    if node == nil or node == 0 then return nil end
    while true do
        if getUserAttribute(node, "polygonIndex") ~= nil then return node end
        if node == getRootNode() then return nil end
        node = getParent(node)
    end
    return nil
end

-- ==================================================================
-- FIELD SIZES & NOTES LOGIC
-- ==================================================================

function FieldToolkit:calculateTotalSize()
    local fieldNode = FieldUtil.getFieldsRootNode()
    if fieldNode == nil then return end

    local totalFarmland = 0
    local totalActual = 0

    for i=0, getNumOfChildren(fieldNode)-1 do
        local field = getChildAt(fieldNode, i)
        local fTotal, fActual = FieldToolkit.getFieldSizes(field)
        totalFarmland = totalFarmland + fTotal
        totalActual = totalActual + fActual
    end

    print(string.format("Calculated total map sizes: Farmland = %.2f ha | Cultivated = %.2f ha", totalFarmland, totalActual))
    MessageBox.show("Field Size", string.format("Total Farmland Area: %.2f ha\nTotal Cultivated Area: %.2f ha", totalFarmland, totalActual))
end

function FieldToolkit:updateFieldSizes(selectedNode, isUpdateAll)
    local fieldNode = FieldUtil.getFieldsRootNode()
    if fieldNode == nil then return end

    if not isUpdateAll then
        local selectedField = self:getFieldRootByNode(selectedNode)
        if selectedField == nil then
            printError("Please select a 'fieldXXX' in the scenegraph to update, or use 'Update All'.")
            return
        end
        FieldToolkit.updateFieldNote(selectedField)
        print(string.format("Updated field sizes and note for '%s'", getName(selectedField)))
    else
        for i=0, getNumOfChildren(fieldNode)-1 do
            local field = getChildAt(fieldNode, i)
            FieldToolkit.updateFieldNote(field)
        end
        print("Updated field sizes and notes for all fields on the map.")
    end
end

-- Calculates 2D polygon area in hectares using the Shoelace formula
function FieldToolkit.getPolygonArea(polygonPointsGroup)
    if polygonPointsGroup ~= nil and getNumOfChildren(polygonPointsGroup) >= 3 then
        local size = 0
        local lastPoint = getChildAt(polygonPointsGroup, getNumOfChildren(polygonPointsGroup)-1)
        for i=0, getNumOfChildren(polygonPointsGroup)-1 do
            local point = getChildAt(polygonPointsGroup, i)
            local x1, _, z1 = getWorldTranslation(point)
            local x2, _, z2 = getWorldTranslation(lastPoint)
            size = size + ((x2 - x1) * ((z1 + z2) * 0.5))
            lastPoint = point
        end
        return math.abs(size) / 10000 -- Convert m^2 to ha
    end
    return 0
end

-- Returns two values: Total Farmland Area, Actual Cultivated Area (minus exclusions)
function FieldToolkit.getFieldSizes(fieldNode)
    local indexPath = getUserAttribute(fieldNode, "polygonIndex")
    local polygonPoints = EditorUtils.getNodeByIndexPath(indexPath, fieldNode)

    local totalArea = FieldToolkit.getPolygonArea(polygonPoints)
    local actualArea = totalArea

    local exclusionIndexPath = getUserAttribute(fieldNode, "exclusionIndex")
    if exclusionIndexPath ~= nil then
        local exclusionPointsRoot = EditorUtils.getNodeByIndexPath(exclusionIndexPath, fieldNode)
        if exclusionPointsRoot ~= nil then
            for e=0, getNumOfChildren(exclusionPointsRoot)-1 do
                local exclusionPoly = getChildAt(exclusionPointsRoot, e)
                -- Subtract the area of each valid exclusion hole
                actualArea = actualArea - FieldToolkit.getPolygonArea(exclusionPoly)
            end
        end
    end

    return totalArea, math.max(0, actualArea)
end

function FieldToolkit.updateFieldNote(field)
    local indicatorPath = getUserAttribute(field, "nameIndicatorIndex")
    local indicator = EditorUtils.getNodeByIndexPath(indicatorPath, field)
    if indicator ~= nil and getNumOfChildren(indicator) == 1 then
        local totalArea, actualArea = FieldToolkit.getFieldSizes(field)

        -- Multi-line note showing both the bounding farmland and the net field area
        local noteName = string.format("%s\nFarmland: %.2f ha\nCultivated: %.2f ha", getName(field), totalArea, actualArea)
        local note = getChildAt(indicator, 0)

        if getNoteNodeText(note) ~= noteName then
            setNoteNodeText(note, noteName)
        end
    end
end

function FieldToolkit:toggleNoteRendering()
    local fieldNode = FieldUtil.getFieldsRootNode()
    if fieldNode == nil then return end

    local isActive
    for i=0, getNumOfChildren(fieldNode)-1 do
        local field = getChildAt(fieldNode, i)
        local indicatorPath = getUserAttribute(field, "nameIndicatorIndex")
        local indicator = EditorUtils.getNodeByIndexPath(indicatorPath, field)
        if indicator ~= nil and getNumOfChildren(indicator) == 1 then
            local note = getChildAt(indicator, 0)
            if isActive == nil then
                isActive = not getVisibility(note)
            end
            setVisibility(note, isActive)
            if isActive then
                FieldToolkit.updateFieldNote(field)
            end
        end
    end

    if isActive ~= nil then
        print("Toggled field notes visibility to: " .. tostring(isActive))
    end
end

-- ==================================================================
-- DEBUG RENDERING
-- ==================================================================
function FieldToolkit:toggleDebugRendering()
    self.fieldRootNode = nil
    self.terrainNode = nil
    self.colorByField = {}

    if self.isDebugRenderingActive then
        if self.drawCallback ~= nil then
            removeDrawListener(self.drawCallback)
            self.drawCallback = nil
        end
        self.isDebugRenderingActive = false
        print("Disabled debug rendering")
        return
    end

    local fieldNode = FieldUtil.getFieldsRootNode()
    if fieldNode == nil then return end
    local terrainNode = EditorUtils.getIdsByName("terrain")[1]
    if terrainNode == nil then return end

    self.fieldRootNode = fieldNode
    self.terrainNode = terrainNode
    self.isDebugRenderingActive = true
    self.drawCallback = addDrawListener("fieldToolkit_debugDrawCallback", self, self.draw)
    print("Activated field debug rendering")
end

function FieldToolkit:deactivateDebugRendering()
    if self.isDebugRenderingActive then self:toggleDebugRendering() end
end

function FieldToolkit:draw()
    if not entityExists(self.fieldRootNode) or not entityExists(self.terrainNode) then
        self:toggleDebugRendering()
        return
    end

    local safeFrame = 3 -- 3m red border width

    for fieldIndex=0, getNumOfChildren(self.fieldRootNode)-1 do
        local fieldNode = getChildAt(self.fieldRootNode, fieldIndex)
        if self.colorByField[fieldIndex] == nil then
            self.colorByField[fieldIndex] = {math.random(), math.random(), math.random(), 0.4}
        end
        local r, g, b, a = unpack(self.colorByField[fieldIndex])

        local indexPath = getUserAttribute(fieldNode, "polygonIndex")
        local polygonPoints = EditorUtils.getNodeByIndexPath(indexPath, fieldNode)

        if polygonPoints ~= nil and getNumOfChildren(polygonPoints) > 0 then
            local positions = {}
            local sum = 0
            local lastNode = getChildAt(polygonPoints, getNumOfChildren(polygonPoints)-1)

            for i=0, getNumOfChildren(polygonPoints)-1 do
                local point = getChildAt(polygonPoints, i)
                local x, y, z = getWorldTranslation(point)
                local ty = getTerrainHeightAtWorldPos(self.terrainNode, x, y, z) + 0.1

                table.insert(positions, x)
                table.insert(positions, ty)
                table.insert(positions, z)

                local lastX, lastY, lastZ = getWorldTranslation(lastNode)
                drawDebugLine(x, y, z, 0, 0, 0, lastX, lastY, lastZ, 0, 0, 0, false)
                drawDebugPoint(x, y, z, 0, 0, 0, 1, false)

                sum = sum + (x-lastX)*(z+lastZ)
                lastNode = point
            end

            if #positions >= 9 then
                local dir = -1
                if sum > 0 then dir = 1 end

                local lastX = positions[#positions-2]
                local lastY = positions[#positions-1]
                local lastZ = positions[#positions]

                local safeFramePos = {}
                for i=1, #positions, 3 do
                    local x = positions[i]
                    local y = positions[i+1]
                    local z = positions[i+2]

                    local dx, dy, dz = x-lastX, y-lastY, z-lastZ
                    if dx ~= 0 or dy ~= 0 or dz ~= 0 then
                        local dirX, dirY, dirZ = MathUtil.vector3Normalize(dx, dy, dz)
                        local normX, normY, normZ

                        if dir > 0 then
                            normX, normY, normZ = MathUtil.crossProduct(dirX, dirY, dirZ, 0, 1, 0)
                        else
                            normX, normY, normZ = MathUtil.crossProduct(0, 1, 0, dirX, dirY, dirZ)
                        end

                        normX = normX * safeFrame
                        normY = normY * safeFrame
                        normZ = normZ * safeFrame

                        local xOffset, yOffset, zOffset = x + normX, y + normY, z + normZ
                        local lastXOffset, lastYOffset, lastZOffset = lastX + normX, lastY + normY, lastZ + normZ

                        safeFramePos[1] = x; safeFramePos[2] = y; safeFramePos[3] = z
                        safeFramePos[4] = lastX; safeFramePos[5] = lastY; safeFramePos[6] = lastZ
                        safeFramePos[7] = lastXOffset; safeFramePos[8] = lastYOffset; safeFramePos[9] = lastZOffset
                        safeFramePos[10] = xOffset; safeFramePos[11] = yOffset; safeFramePos[12] = zOffset

                        drawDebugPolygon(safeFramePos, 1, 0, 0, 0.4, false)
                    end
                    lastX = x; lastY = y; lastZ = z
                end
            end

            drawDebugPolygon(positions, r, g, b, a, false)
        end

        local exclusionIndexPath = getUserAttribute(fieldNode, "exclusionIndex")
        if exclusionIndexPath ~= nil then
            local exclusionPointsRoot = EditorUtils.getNodeByIndexPath(exclusionIndexPath, fieldNode)
            if exclusionPointsRoot ~= nil then
                for e=0, getNumOfChildren(exclusionPointsRoot)-1 do
                    local exclusionPoly = getChildAt(exclusionPointsRoot, e)
                    if getNumOfChildren(exclusionPoly) >= 3 then
                        local excPositions = {}
                        local excLastNode = getChildAt(exclusionPoly, getNumOfChildren(exclusionPoly)-1)

                        local eLastX, _, eLastZ = getWorldTranslation(excLastNode)
                        local eLastTY = getTerrainHeightAtWorldPos(self.terrainNode, eLastX, 0, eLastZ) + 0.15

                        for k=0, getNumOfChildren(exclusionPoly)-1 do
                            local excPoint = getChildAt(exclusionPoly, k)
                            local ex, _, ez = getWorldTranslation(excPoint)
                            local ety = getTerrainHeightAtWorldPos(self.terrainNode, ex, 0, ez) + 0.15

                            table.insert(excPositions, ex)
                            table.insert(excPositions, ety)
                            table.insert(excPositions, ez)

                            drawDebugLine(ex, ety, ez, 1, 0.5, 0, eLastX, eLastTY, eLastZ, 1, 0.5, 0, false)
                            drawDebugPoint(ex, ety, ez, 1, 0.5, 0, 1, false)

                            eLastX = ex
                            eLastTY = ety
                            eLastZ = ez
                        end
                        drawDebugPolygon(excPositions, 1, 0.5, 0, 0.5, false)
                    end
                end
            end
        end
    end
end

FieldToolkit.new()