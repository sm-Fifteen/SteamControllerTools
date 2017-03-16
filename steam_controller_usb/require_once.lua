return function(name,...)
    local fn=require(name)
    package.loaded[name]=nil
    return fn
end