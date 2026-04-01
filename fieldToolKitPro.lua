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
FieldToolkit.WINDOW_WIDTH = 600
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

    self.helpTexts.createFieldPoints = [[HOW TO: Create Field (Points)
1. Navigate the camera to where you want the field to start.
2. Click 'Create Field (Points)'.
3. A new 'fieldXXX' Transform Group is created at the origin (0,0,0).
4. The first point ('point1') and the indicators are placed exactly in front of your camera.
5. Select 'point1', duplicate it (CTRL+D), and position the points around your field boundary.]]

    self.helpTexts.createFieldSpline = [[HOW TO: Create Field (from Spline)
1. Use the GIANTS Editor to draw a spline where your field boundary should be (Create -> Spline).
2. Select the spline in the Scenegraph.
3. Click 'Create Field (from Spline)'.
4. The script will automatically create a new field and convert the spline's curve into perfectly ground-aligned polygon points.]]

    self.helpTexts.addExclPoints = [[HOW TO: Add Exclusion (Points)
Use this to create "holes" (like grass strips or water ditches) inside your fields.
1. Select the main 'fieldXXX' Transform Group in the Scenegraph.
2. Click 'Add Exclusion (Points)'.
3. The script automatically creates the 'exclusionPoints' folder (if missing) and adds a new, sequentially numbered 'exclusionX' group.
4. The first point of this new exclusion zone is placed in front of your camera.
5. Duplicate the point and outline the area you want to subtract from the field.]]

    self.helpTexts.addExclSpline = [[HOW TO: Add Exclusion (from Spline)
1. Draw a spline outlining the hole/ditch you want to cut out of the field.
2. Select BOTH the main 'fieldXXX' AND the drawn spline in the Scenegraph (CTRL + Click).
3. Click 'Add Exclusion (from Spline)'.
4. The script automatically creates the necessary exclusion folders and converts the spline into perfectly aligned polygon points.]]

    self.helpTexts.repaint = [[HOW TO: Repaint Fields
1. Select a 'fieldXXX' or leave unselected to process all fields.
2. Click 'Repaint Fields'.
3. The script will paint the main polygon boundary.
4. Immediately after, it will read all your 'exclusionX' groups and perfectly punch those holes back out of the terrainDetail layer.]]

    self.helpTexts.center = [[HOW TO: Center Indicators (Bounding Box)
1. Select a 'fieldXXX' group or leave unselected to process all fields at once.
2. Click 'Center Indicators (Bounding Box)'.
3. The script calculates a virtual bounding box around the field boundaries.
4. The nameIndicator and teleportIndicator are moved to the exact geometric center, completely ignoring uneven point densities along curved edges.]]
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
function FieldToolkit:generateUI()
    local frameRowSizer = UIRowLayoutSizer.new()
    self.window = UIWindow.new(frameRowSizer, "Field Toolkit Pro")

    local borderSizer = UIRowLayoutSizer.new()
    UIPanel.new(frameRowSizer, borderSizer, -1, -1, -1, -1, BorderDirection.NONE, 0, 1)
    local rowSizer = UIRowLayoutSizer.new()
    UIPanel.new(borderSizer, rowSizer, -1, -1, FieldToolkit.WINDOW_WIDTH, FieldToolkit.WINDOW_HEIGHT, BorderDirection.ALL, 10, 1)

    -- ############ 1. FIELD CREATION ############
    local colSizer = UIColumnLayoutSizer.new()
    UIPanel.new(rowSizer, colSizer, -1, -1, -1, -1, BorderDirection.BOTTOM, 5, 1)
    local title = UILabel.new(colSizer, "1. Field Creation", false, TextAlignment.LEFT, VerticalAlignment.CENTER, -1, -1, FieldToolkit.TEXT_WIDTH, FieldToolkit.TEXT_HEIGHT, BorderDirection.BOTTOM, 0)
    title:setBold(true)

    local btnSizer1 = UIRowLayoutSizer.new(); UIPanel.new(colSizer, btnSizer1)
    UIButton.new(btnSizer1, "Create Field (Points)", function() self:createField(false) end, self)
    UIButton.new(btnSizer1, "(?)", function() self:showHelp("createFieldPoints") end, self, -1, -1, 30, -1, BorderDirection.LEFT, 5)

    local btnSizer2 = UIRowLayoutSizer.new(); UIPanel.new(colSizer, btnSizer2, -1,-1,-1,-1, BorderDirection.TOP, 2)
    UIButton.new(btnSizer2, "Create Field (from Spline)", function() self:createField(true) end, self)
    UIButton.new(btnSizer2, "(?)", function() self:showHelp("createFieldSpline") end, self, -1, -1, 30, -1, BorderDirection.LEFT, 5)

    UIHorizontalLine.new(rowSizer, -1, -1, -1, -1, BorderDirection.BOTTOM, 5)

    -- ############ 2. FIELD EXCLUSIONS ############
    local colSizer2 = UIColumnLayoutSizer.new()
    UIPanel.new(rowSizer, colSizer2, -1, -1, -1, -1, BorderDirection.BOTTOM, 5, 1)
    local title2 = UILabel.new(colSizer2, "2. Field Exclusions (Holes)", false, TextAlignment.LEFT, VerticalAlignment.CENTER, -1, -1, FieldToolkit.TEXT_WIDTH, FieldToolkit.TEXT_HEIGHT, BorderDirection.BOTTOM, 0)
    title2:setBold(true)

    local btnSizer3 = UIRowLayoutSizer.new(); UIPanel.new(colSizer2, btnSizer3)
    UIButton.new(btnSizer3, "Add Exclusion (Points)", function() self:addExclusion(false) end, self)
    UIButton.new(btnSizer3, "(?)", function() self:showHelp("addExclPoints") end, self, -1, -1, 30, -1, BorderDirection.LEFT, 5)

    local btnSizer4 = UIRowLayoutSizer.new(); UIPanel.new(colSizer2, btnSizer4, -1,-1,-1,-1, BorderDirection.TOP, 2)
    UIButton.new(btnSizer4, "Add Exclusion (from Spline)", function() self:addExclusion(true) end, self)
    UIButton.new(btnSizer4, "(?)", function() self:showHelp("addExclSpline") end, self, -1, -1, 30, -1, BorderDirection.LEFT, 5)

    -- ############ HELP PANEL (Hidden by default) ############
    local helpPanelSizer = UIRowLayoutSizer.new()
    self.helpPanel = UIPanel.new(rowSizer, helpPanelSizer, -1, -1, -1, -1, BorderDirection.ALL, 5, 1)
    self.helpTextArea = UITextArea.new(helpPanelSizer, "", TextAlignment.LEFT, true, true, -1, -1, 580, 140)
    UIButton.new(helpPanelSizer, "Close Help", function() self:hideHelp() end, self, -1, -1, -1, 22, BorderDirection.TOP, 5)
    self.helpPanel:setVisible(false)

    UIHorizontalLine.new(rowSizer, -1, -1, -1, -1, BorderDirection.BOTTOM, 5)

    -- ############ 3. FIELD MAINTENANCE ############
    local columnSizer = UIColumnLayoutSizer.new()
    UIPanel.new(rowSizer, columnSizer, -1, -1, -1, -1, BorderDirection.BOTTOM, 5)
    local title3 = UILabel.new(columnSizer, "3. Field Maintenance & Painting", false, TextAlignment.LEFT, VerticalAlignment.CENTER, -1, -1, FieldToolkit.TEXT_WIDTH, FieldToolkit.TEXT_HEIGHT, BorderDirection.BOTTOM, 0)
    title3:setBold(true)

    local btnRow = UIRowLayoutSizer.new(); UIPanel.new(columnSizer, btnRow)
    UIButton.new(btnRow, "Repaint Fields", function() self:repaintFields(getSelection(0)) end, self)
    UIButton.new(btnRow, "(?)", function() self:showHelp("repaint") end, self, -1, -1, 30, -1, BorderDirection.LEFT, 5)

    UIButton.new(columnSizer, "Repaint Fields to Farmland", function() self:repaintFarmlandFields(getSelection(0)) end, self, -1, -1, -1, -1, BorderDirection.BOTTOM, 2, 1)

    -- NEW: Center Indicators button with help icon
    local btnRowCenter = UIRowLayoutSizer.new(); UIPanel.new(columnSizer, btnRowCenter, -1, -1, -1, -1, BorderDirection.BOTTOM, 2)
    UIButton.new(btnRowCenter, "Center Indicators (Bounding Box)", function() self:centerIndicators(getSelection(0)) end, self)
    UIButton.new(btnRowCenter, "(?)", function() self:showHelp("center") end, self, -1, -1, 30, -1, BorderDirection.LEFT, 5)

    UIButton.new(columnSizer, "Align Polygon Points To Terrain", function() self:alignPolygonPointsToTerrain(getSelection(0)) end, self, -1, -1, -1, -1, BorderDirection.BOTTOM, 2, 1)
    UIButton.new(columnSizer, "Rename Polygon Points", function() self:renamePolygonPoints(getSelection(0)) end, self, -1, -1, -1, -1, BorderDirection.BOTTOM, 2, 1)
    UIButton.new(columnSizer, "Validate Fields", function() self:validateFields(getSelection(0)) end, self, -1, -1, -1, -1, BorderDirection.BOTTOM, 2, 1)
    UIButton.new(columnSizer, "Update Field Sizes", function() self:updateFieldSizes(getSelection(0)) end, self, -1, -1, -1, -1, BorderDirection.BOTTOM, 2, 1)
    UIButton.new(columnSizer, "Clear Field Ground", function() self:clearFieldGround(getSelection(0)) end, self, -1, -1, -1, -1, BorderDirection.BOTTOM, 2, 1)

    UIHorizontalLine.new(rowSizer, -1, -1, -1, -1, BorderDirection.BOTTOM, 5)

    local debugSizer = UIColumnLayoutSizer.new()
    UIPanel.new(rowSizer, debugSizer, -1, -1, -1, -1, BorderDirection.BOTTOM, 5)
    local envTitle = UILabel.new(debugSizer, "Debug", false, TextAlignment.LEFT, VerticalAlignment.CENTER, -1, -1, FieldToolkit.TEXT_WIDTH, FieldToolkit.TEXT_HEIGHT, BorderDirection.BOTTOM, 0)
    envTitle:setBold(true)
    UIButton.new(debugSizer, "Toggle Debug Rendering", function() self:toggleDebugRendering() end, self, -1, -1, -1, -1, BorderDirection.BOTTOM, 2, 1)

    -- layout and show window
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

-- Extracts points from a given spline node and creates transform groups under the parentNode
function FieldToolkit:_splineToPoints(splineNode, parentNode, terrainNode)
    if not getHasClassId(splineNode, ClassIds.SHAPE) or not getHasClassId(getGeometry(splineNode), ClassIds.SPLINE) then
        return false
    end

    for j = 0, getSplineNumOfCV(splineNode) - 1 do
        -- Get local CV coordinates
        local cx, cy, cz = getSplineCV(splineNode, j)

        -- Convert to world coordinates to fetch correct terrain height
        local wx, wy, wz = localToWorld(splineNode, cx, cy, cz)
        local ty = getTerrainHeightAtWorldPos(terrainNode, wx, 0, wz)

        -- Convert back to local coordinates relative to the target parent transform group
        local lx, ly, lz = worldToLocal(parentNode, wx, ty, wz)

        local pointTG = createTransformGroup("point" .. tostring(j + 1))
        setTranslation(pointTG, lx, ly, lz)
        link(parentNode, pointTG)
    end
    return true
end

-- Generates the base structure (indicators, attributes) for a new field
function FieldToolkit:_generateBaseFieldStructure(fieldNode, newFieldName, spawnX, spawnY, spawnZ)
    local field = createTransformGroup(newFieldName)
    link(fieldNode, field)

    local polygonPoints = createTransformGroup("polygonPoints")
    local nameIndicator = createTransformGroup("nameIndicator")
    local teleportIndicator = createTransformGroup("teleportIndicator")

    local note = createNoteNode(nameIndicator, newFieldName, 0, 0, 0, true)
    link(nameIndicator, note)

    -- Place indicators at spawn location
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


-- Creates a field either from camera position or from a selected spline
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
        -- Use the first CV of the spline as the indicator spawn point
        local cx, cy, cz = getSplineCV(splineNode, 0)
        spawnX, spawnY, spawnZ = localToWorld(splineNode, cx, cy, cz)
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
    addSelection(field)
    return field
end


-- Smartly adds an exclusion zone to a selected field (via points or spline)
function FieldToolkit:addExclusion(fromSpline)
    local terrainNode = EditorUtils.getIdsByName("terrain")[1]
    if terrainNode == nil then return end

    local field = nil
    local splineNode = nil

    -- Determine selection based on mode
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

    -- 1. Get or create the 'exclusionPoints' container
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

    -- 2. Determine the next available exclusion ID
    local nextId = 1
    for i = 0, getNumOfChildren(exclusionPointsRoot) - 1 do
        local child = getChildAt(exclusionPointsRoot, i)
        local num = tonumber(getName(child):match("^exclusion(%d+)"))
        if num and num >= nextId then
            nextId = num + 1
        end
    end

    -- 3. Create the new exclusion folder
    local newExclName = "exclusion" .. nextId
    local newExclGroup = createTransformGroup(newExclName)
    link(exclusionPointsRoot, newExclGroup)

    -- 4. Populate the folder
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


function FieldToolkit:repaintFields(selectedNode)
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

    local selectedField = self:getFieldRootByNode(selectedNode)

    local terrainDetail, _ = getTerrainDataPlaneByName(terrainNode, "terrainDetail")
    local modifier = DensityMapModifier.new(terrainDetail, 0, 4, terrainNode)

    for i=0, getNumOfChildren(fieldNode)-1 do
        local field = getChildAt(fieldNode, i)
        if selectedField == nil or selectedField == field then
            local indexPath = getUserAttribute(field, "polygonIndex")
            local polygon = EditorUtils.getNodeByIndexPath(indexPath, field)

            if polygon ~= nil then
                -- STEP 1: Paint the main field boundary
                modifier:clearPolygonPoints()

                for j=0, getNumOfChildren(polygon)-1 do
                    local polygonPoint = getChildAt(polygon, j)
                    local x, _, z = getWorldTranslation(polygonPoint)
                    modifier:addPolygonPointWorldCoords(x, z)
                end

                modifier:executeSet(2)
                print("    Repainted field '"..getName(field).."'")

                -- STEP 2: Punch out multiple exclusion zones
                local exclusionIndexPath = getUserAttribute(field, "exclusionIndex")
                if exclusionIndexPath ~= nil then
                    local exclusionPointsRoot = EditorUtils.getNodeByIndexPath(exclusionIndexPath, field)

                    if exclusionPointsRoot ~= nil then
                        for e=0, getNumOfChildren(exclusionPointsRoot)-1 do
                            local exclusionPoly = getChildAt(exclusionPointsRoot, e)

                            -- Only punch if it has at least 3 points to form a surface
                            if getNumOfChildren(exclusionPoly) >= 3 then
                                modifier:clearPolygonPoints()

                                for k=0, getNumOfChildren(exclusionPoly)-1 do
                                    local excPoint = getChildAt(exclusionPoly, k)
                                    local ex, _, ez = getWorldTranslation(excPoint)
                                    modifier:addPolygonPointWorldCoords(ex, ez)
                                end

                                modifier:executeSet(0) -- 0 = clear ground
                                print("      -> Punched exclusion zone '"..getName(exclusionPoly).."' in field '"..getName(field).."'")
                            end
                        end
                    end
                end

            else
                print("    Could not repaint field '"..getName(field).."'. Cannot find field 'polygonIndex'")
            end
        end

        FieldToolkit.updateFieldNote(field)
    end

    print("Repainted fields")
end

-- ==================================================================
-- UTILITY & MAINTENANCE METHODS
-- ==================================================================

function FieldToolkit:alignPolygonPointsToTerrain(selectedNode)
    local fieldNode = FieldUtil.getFieldsRootNode()
    if fieldNode == nil then return end
    local terrainNode = EditorUtils.getIdsByName("terrain")[1]
    if terrainNode == nil then return end

    local selectedField = self:getFieldRootByNode(selectedNode)

    for i=0, getNumOfChildren(fieldNode)-1 do
        local field = getChildAt(fieldNode, i)
        if selectedField == nil or selectedField == field then

            -- STEP 1: Align Main Polygon
            local indexPath = getUserAttribute(field, "polygonIndex")
            local polygon = EditorUtils.getNodeByIndexPath(indexPath, field)
            if polygon ~= nil then
                for j=0, getNumOfChildren(polygon)-1 do
                    local polygonPoint = getChildAt(polygon, j)
                    local x, y, z = getWorldTranslation(polygonPoint)
                    y = getTerrainHeightAtWorldPos(terrainNode, x, y, z)
                    setWorldTranslation(polygonPoint, x, y, z)
                end
                print("    Aligned main polygon points for field '"..getName(field).."'")
            end

            -- STEP 2: Align Exclusion Points
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
                    print("    Aligned exclusion points for field '"..getName(field).."'")
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

            -- STEP 1: Rename Main Polygon Points
            local indexPath = getUserAttribute(field, "polygonIndex")
            local polygon = EditorUtils.getNodeByIndexPath(indexPath, field)
            if polygon ~= nil then
                for j=0, getNumOfChildren(polygon)-1 do
                    local polygonPoint = getChildAt(polygon, j)
                    setName(polygonPoint, string.format("point%d", j+1))
                end
            end

            -- STEP 2: Rename Exclusion Folders and Points
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

                print(string.format("    Centered indicators (Bounding Box) for field '%s'", getName(field)))
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

                    print(string.format("  Validate field '"..getName(field).."' (Farmland '%d')", farmlandId))

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
                else
                    printError("  Error: No polygon points defined in node '" .. getName(polygon) .. "'")
                end
            end

            -- Check Duplicate Vertices for Exclusions
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
                print("    Repainted field '"..getName(field).."' to farmlands")
            end
        end
    end
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

function FieldToolkit:updateFieldSizes(selectedNode)
    local fieldNode = FieldUtil.getFieldsRootNode()
    if fieldNode == nil then return end
    local selectedField = self:getFieldRootByNode(selectedNode)

    for i=0, getNumOfChildren(fieldNode)-1 do
        local field = getChildAt(fieldNode, i)
        if selectedField == nil or selectedField == field then
            FieldToolkit.updateFieldNote(field)
        end
    end
end

function FieldToolkit.getFieldSize(fieldNode)
    local indexPath = getUserAttribute(fieldNode, "polygonIndex")
    local polygonPoints = EditorUtils.getNodeByIndexPath(indexPath, fieldNode)
    if polygonPoints ~= nil and getNumOfChildren(polygonPoints) >= 3 then
        local size = 0
        local lastPoint = getChildAt(polygonPoints, getNumOfChildren(polygonPoints)-1)
        for i=0, getNumOfChildren(polygonPoints)-1 do
            local point = getChildAt(polygonPoints, i)
            local x1, _, z1 = getWorldTranslation(point)
            local x2, _, z2 = getWorldTranslation(lastPoint)
            size = size + ((x2 - x1) * ((z1 + z2) * 0.5))
            lastPoint = point
        end
        return math.abs(size) / 10000
    end
    return 0
end

function FieldToolkit.updateFieldNote(field)
    local indicatorPath = getUserAttribute(field, "nameIndicatorIndex")
    local indicator = EditorUtils.getNodeByIndexPath(indicatorPath, field)
    if indicator ~= nil and getNumOfChildren(indicator) == 1 then
        local fieldSize = FieldToolkit.getFieldSize(field)
        local noteName = string.format("%s\n%.2f ha", getName(field), fieldSize)
        local note = getChildAt(indicator, 0)
        if getNoteNodeText(note) ~= noteName then
            setNoteNodeText(note, noteName)
        end
    end
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
                lastNode = point
            end
            drawDebugPolygon(positions, r, g, b, a, true)
        end

        -- Draw Exclusions in orange
        local exclusionIndexPath = getUserAttribute(fieldNode, "exclusionIndex")
        if exclusionIndexPath ~= nil then
            local exclusionPointsRoot = EditorUtils.getNodeByIndexPath(exclusionIndexPath, fieldNode)
            if exclusionPointsRoot ~= nil then
                for e=0, getNumOfChildren(exclusionPointsRoot)-1 do
                    local exclusionPoly = getChildAt(exclusionPointsRoot, e)
                    if getNumOfChildren(exclusionPoly) >= 3 then
                        local excPositions = {}
                        local excLastNode = getChildAt(exclusionPoly, getNumOfChildren(exclusionPoly)-1)

                        for k=0, getNumOfChildren(exclusionPoly)-1 do
                            local excPoint = getChildAt(exclusionPoly, k)
                            local ex, ey, ez = getWorldTranslation(excPoint)
                            local ety = getTerrainHeightAtWorldPos(self.terrainNode, ex, ey, ez) + 0.15

                            table.insert(excPositions, ex)
                            table.insert(excPositions, ety)
                            table.insert(excPositions, ez)

                            local eLastX, eLastY, eLastZ = getWorldTranslation(excLastNode)
                            drawDebugLine(ex, ety, ez, 1, 0.5, 0, eLastX, eLastY + 0.15, eLastZ, 1, 0.5, 0, false)
                            drawDebugPoint(ex, ety, ez, 1, 0.5, 0, 1, false)
                            excLastNode = excPoint
                        end
                        drawDebugPolygon(excPositions, 1, 0.5, 0, 0.5, true)
                    end
                end
            end
        end
    end
end

FieldToolkit.new()