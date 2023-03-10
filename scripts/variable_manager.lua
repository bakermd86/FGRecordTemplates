local typeChangeCallbacks = {}
local varTypeDataMap = {
    ["Table"] = "insertTableName",
    ["Record Type"] = "insertRecordClass",
    ["Exclusive Group"] = "insertExclusiveGroup",
    ["Story Template"] = "insertStoryTemplate",
}

function getPathValues(valPath)
    local vals = {}
    if (valPath or "") == "" then
        return vals
    end
    if valPath == "records"then
        return getRecordTypes()
    end
    for _, childNode in pairs(DB.getChildren(valPath)) do
        table.insert(vals, DB.getValue(childNode, "name", ""))
    end
    return vals
end

function onChangeCallback(nodeChanged)
    local valPath = nodeChanged.getParent().getName()
    local vals = getPathValues(valPath)
    local callback = typeChangeCallbacks[valPath]
    if ((vals or "") ~= "") and ((callback or "") ~= "") then
        callback(vals)
    end
end

function registerTypeChangeCallback(valPath, callback)
    typeChangeCallbacks[valPath] = callback
    DB.addHandler(valPath, "onIntegrityChange", onChangeCallback)
end

function getRecordTypes()
    local visibleRecords = {}
    for _, recordName in ipairs(LibraryData.getRecordTypes()) do
        if not LibraryData.isHidden(recordName) then
            table.insert(visibleRecords, recordName)
        end
    end
    return visibleRecords
end
