local _dataType = ""

function onInit()
    super.onInit()
    if data_type then
        _dataType = data_type[1]
    end
    if _dataType then
        VariableManager.registerTypeChangeCallback(_dataType, self.onChange)
    end
    self.addItems(VariableManager.getPathValues(_dataType))
end

function onChange(vals)
    self.clear()
    self.addItems(vals)
end