function add_default_code_class(el)
  if #(el.classes) == 0 then
    el.classes = {"numberLines", "lineAnchors"}
    return el
  else
    table.insert(el.classes, "numberLines")
    table.insert(el.classes, "lineAnchors")
    return el
  end
end

return {{Code = add_default_code_class},
        {CodeBlock = add_default_code_class}}
