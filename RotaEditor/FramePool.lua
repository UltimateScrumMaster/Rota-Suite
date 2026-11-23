-- RotaEditor/FramePool.lua — Zero-Leak Frame Recycling Pool for WoW 3.3.5a
local RotaEditor = _G.RotaEditor or {}
_G.RotaEditor = RotaEditor

local FramePool = {}
FramePool.__index = FramePool
RotaEditor.FramePool = FramePool

--- Creates a new FramePool instance.
-- @param frameType string (e.g., "Frame", "Button")
-- @param parent table parent UI frame
-- @param template string optional XML template name
-- @param initFn function optional initialization callback for new frames
-- @return table FramePool instance
function FramePool.New(frameType, parent, template, initFn)
    local pool = {
        frameType = frameType or "Frame",
        parent = parent,
        template = template,
        initFn = initFn,
        active = {},
        inactive = {},
        totalCreated = 0,
    }
    return setmetatable(pool, FramePool)
end

--- Acquires a frame from the pool, reusing an inactive frame or instantiating a new one.
-- @return table frame
function FramePool:Acquire()
    local frame = table.remove(self.inactive)
    if not frame then
        self.totalCreated = self.totalCreated + 1
        local name = "RotaEditorPooledFrame_" .. tostring(self.frameType) .. "_" .. tostring(self.totalCreated)
        frame = _G.CreateFrame(self.frameType, name, self.parent, self.template)
        if self.initFn then
            self.initFn(frame)
        end
    end
    table.insert(self.active, frame)
    frame:Show()
    return frame
end

--- Releases a single frame back into the pool.
-- @param frame table
-- @return boolean true if released
function FramePool:Release(frame)
    for i = 1, #self.active do
        if self.active[i] == frame then
            table.remove(self.active, i)
            frame:Hide()
            if frame.ClearAllPoints then
                frame:ClearAllPoints()
            end
            table.insert(self.inactive, frame)
            return true
        end
    end
    return false
end

--- Releases all currently active frames back into the pool for immediate reuse.
function FramePool:ReleaseAll()
    for i = #self.active, 1, -1 do
        local frame = self.active[i]
        frame:Hide()
        if frame.ClearAllPoints then
            frame:ClearAllPoints()
        end
        table.insert(self.inactive, frame)
        self.active[i] = nil
    end
end

function FramePool:GetActiveCount()
    return #self.active
end

function FramePool:GetInactiveCount()
    return #self.inactive
end

function FramePool:GetTotalCreated()
    return self.totalCreated
end

return FramePool
