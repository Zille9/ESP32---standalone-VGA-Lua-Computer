local function tak(x, y, z)
    if y < x then
        return tak(
            tak(x - 1, y, z),
            tak(y - 1, z, x),
            tak(z - 1, x, y)
        )
    else
        return z
    end
end

local start = sys.timer()
print(tak(36,26,16))
print((sys.timer() - start) / 1000 .. " sek.")

