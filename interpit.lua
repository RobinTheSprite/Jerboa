-- interpit.lua
-- Mark Underwood 
-- Based upon interpit.lua by Glenn G. Chappell, with thanks
-- 3 Apr 2019
--
-- For CS F331 / CSCE A331 Spring 2019
-- Interpret AST from parseit.parse
-- For Assignment 6, Exercise B


-- *******************************************************************
-- * To run a Jerboa program, use jerboa.lua (which uses this file). *
-- *******************************************************************


local interpit = {}  -- Our module


-- ***** Variables *****


-- Symbolic Constants for AST

local STMT_LIST    = 1
local WRITE_STMT   = 2
local FUNC_DEF     = 3
local FUNC_CALL    = 4
local IF_STMT      = 5
local WHILE_STMT   = 6
local RETURN_STMT  = 7
local ASSN_STMT    = 8
local CR_OUT       = 9
local STRLIT_OUT   = 10
local BIN_OP       = 11
local UN_OP        = 12
local NUMLIT_VAL   = 13
local BOOLLIT_VAL  = 14
local READNUM_CALL = 15
local SIMPLE_VAR   = 16
local ARRAY_VAR    = 17



-- ***** Utility Functions *****


-- numToInt
-- Given a number, return the number rounded toward zero.
local function numToInt(n)
    assert(type(n) == "number")

    if n >= 0 then
        return math.floor(n)
    else
        return math.ceil(n)
    end
end


-- strToNum
-- Given a string, attempt to interpret it as an integer. If this
-- succeeds, return the integer. Otherwise, return 0.
local function strToNum(s)
    assert(type(s) == "string")

    -- Try to do string -> number conversion; make protected call
    -- (pcall), so we can handle errors.
    local success, value = pcall(function() return 0+s end)

    -- Return integer value, or 0 on error.
    if success then
        return numToInt(value)
    else
        return 0
    end
end


-- numToStr
-- Given a number, return its string form.
local function numToStr(n)
    assert(type(n) == "number")

    return ""..n
end


-- boolToInt
-- Given a boolean, return 1 if it is true, 0 if it is false.
local function boolToInt(b)
    assert(type(b) == "boolean")

    if b then
        return 1
    else
        return 0
    end
end


-- astToStr
-- Given an AST, produce a string holding the AST in (roughly) Lua form,
-- with numbers replaced by names of symbolic constants used in parseit.
-- A table is assumed to represent an array.
-- See the Assignment 4 description for the AST Specification.
--
-- THIS FUNCTION IS INTENDED FOR USE IN DEBUGGING ONLY!
-- IT SHOULD NOT BE CALLED IN THE FINAL VERSION OF THE CODE.
function astToStr(x)
    local symbolNames = {
        "STMT_LIST", "WRITE_STMT", "FUNC_DEF", "FUNC_CALL", "IF_STMT",
        "WHILE_STMT", "RETURN_STMT", "ASSN_STMT", "CR_OUT",
        "STRLIT_OUT", "BIN_OP", "UN_OP", "NUMLIT_VAL", "BOOLLIT_VAL",
        "READNUM_CALL", "SIMPLE_VAR", "ARRAY_VAR"
    }
    if type(x) == "number" then
        local name = symbolNames[x]
        if name == nil then
            return "<Unknown numerical constant: "..x..">"
        else
            return name
        end
    elseif type(x) == "string" then
        return '"'..x..'"'
    elseif type(x) == "boolean" then
        if x then
            return "true"
        else
            return "false"
        end
    elseif type(x) == "table" then
        local first = true
        local result = "{"
        for k = 1, #x do
            if not first then
                result = result .. ","
            end
            result = result .. astToStr(x[k])
            first = false
        end
        result = result .. "}"
        return result
    elseif type(x) == "nil" then
        return "nil"
    else
        return "<"..type(x)..">"
    end
end


-- ***** Primary Function for Client Code *****


-- interp
-- Interpreter, given AST returned by parseit.parse.
-- Parameters:
--   ast     - AST constructed by parseit.parse
--   state   - Table holding Jerboa variables & functions
--             - AST for function xyz is in state.f["xyz"]
--             - Value of simple variable xyz is in state.v["xyz"]
--             - Value of array item xyz[42] is in state.a["xyz"][42]
--   incall  - Function to call for line input
--             - incall() inputs line, returns string with no newline
--   outcall - Function to call for string output
--             - outcall(str) outputs str with no added newline
--             - To print a newline, do outcall("\n")
-- Return Value:
--   state, updated with changed variable values
function interpit.interp(ast, state, incall, outcall)
    -- Each local interpretation function is given the AST for the
    -- portion of the code it is interpreting. The function-wide
    -- versions of state, incall, and outcall may be used. The
    -- function-wide version of state may be modified as appropriate.


    -- Forward declare local functions
    local interp_stmt_list
    local interp_stmt
    local interp_write_stmt
    local interp_expr


    function interp_stmt_list(ast)
        assert(ast[1] == STMT_LIST,
               "stmt list AST must start w/ STMT_LIST")
        for i = 2, #ast do
            interp_stmt(ast[i])
        end
    end


    function interp_stmt(ast)
        if ast[1] == WRITE_STMT then
            for i = 2, #ast do
            if ast[i][1] == CR_OUT then
                outcall('\n')
            elseif ast[i][1] == STRLIT_OUT then
                local strLength = ast[i][2]:len()
                outcall(ast[i][2]:sub(2,strLength-1))
            else
                outcall(numToStr(interp_expr(ast[i])))
            end
        end
        elseif ast[1] == FUNC_DEF then
            state.f[ast[2]] = ast[3]
        elseif ast[1] == FUNC_CALL then
            local name = ast[2]
            local body = state.f[name]
            if body == nil then
                body = { STMT_LIST }  -- Default AST
            end
            interp_stmt_list(body)
        elseif ast[1] == ASSN_STMT then
            if ast[2][2] ~= "return" then
                if ast[2][1] == SIMPLE_VAR then
                    state.v[ast[2][2]] = interp_expr(ast[3])
                elseif ast[2][1] == ARRAY_VAR then
                    local arrayName = ast[2][2]
                    if state.a[arrayName] == nil then
                        state.a[arrayName] = {}
                    end
                    state.a[arrayName][interp_expr(ast[2][3])] = interp_expr(ast[3])
                end
            end
        elseif ast[1] == IF_STMT then
            local condition
            for i = 2, #ast do
                if ast[i][1] ~= STMT_LIST then
                    condition = interp_expr(ast[i])
                else
                    if condition > 0 then
                        interp_stmt_list(ast[i])
                        break
                    end
                    condition = 1
                end
            end
        elseif ast[1] == WHILE_STMT then
            local condition = interp_expr(ast[2])
            while condition > 0 do
                interp_stmt_list(ast[3])
                condition = interp_expr(ast[2])
            end
        elseif ast[1] == RETURN_STMT then
            state.v["return"] = interp_expr(ast[2])
        end
    end
    
    
    function interp_expr(ast)
        if ast[1] == NUMLIT_VAL then
            return strToNum(ast[2])
        elseif ast[1] == BOOLLIT_VAL then
            if ast[2] == "true" then
                return 1
            else
                return 0
            end
        elseif ast[1] == READNUM_CALL then
            local value = strToNum(incall())
            return value
        elseif ast[1] == SIMPLE_VAR then
            local varValue = state.v[ast[2]]
            if varValue ~= nil then
                return varValue
            else
                return 0
            end
        elseif ast[1] == ARRAY_VAR then
            local arrayName = state.a[ast[2]]
            if arrayName ~= nil then
                local arrayVal = state.a[ast[2]][interp_expr(ast[3])]
                if arrayVal ~= nil then
                    return arrayVal
                else
                    return 0
                end
            else
                return 0
            end
        elseif ast[1] == FUNC_CALL then
            interp_stmt(ast)
            if state.v["return"] ~= nil then
                return state.v["return"]
            else
                return 0
            end
        elseif ast[1][1] == BIN_OP then
            if ast[1][2] == "+" then
                return (interp_expr(ast[2]) + interp_expr(ast[3]))
            elseif ast[1][2] == "-" then
                return (interp_expr(ast[2]) - interp_expr(ast[3]))
            elseif ast[1][2] == "*" then
                return (interp_expr(ast[2]) * interp_expr(ast[3]))
            elseif ast[1][2] == "/" then
                local divisor = interp_expr(ast[3])
                if divisor ~= 0 then
                    return (numToInt(interp_expr(ast[2]) / divisor))
                else
                    return 0
                end
            elseif ast[1][2] == "%" then
                local divisor = interp_expr(ast[3])
                if divisor ~= 0 then
                    return (numToInt(interp_expr(ast[2]) % divisor))
                else
                    return 0
                end
            elseif ast[1][2] == "==" then
                return boolToInt(interp_expr(ast[2]) == interp_expr(ast[3]))
            elseif ast[1][2] == "!=" then
                return boolToInt(interp_expr(ast[2]) ~= interp_expr(ast[3]))
            elseif ast[1][2] == "<" then
                return boolToInt(interp_expr(ast[2]) < interp_expr(ast[3]))
            elseif ast[1][2] == ">" then
                return boolToInt(interp_expr(ast[2]) > interp_expr(ast[3]))
            elseif ast[1][2] == ">=" then
                return boolToInt(interp_expr(ast[2]) >= interp_expr(ast[3]))
            elseif ast[1][2] == "<=" then
                return boolToInt(interp_expr(ast[2]) <= interp_expr(ast[3]))
            elseif ast[1][2] == "&&" then
                return boolToInt(interp_expr(ast[2]) > 0 and interp_expr(ast[3]) > 0)
            elseif ast[1][2] == "||" then
                return boolToInt(interp_expr(ast[2]) > 0 or interp_expr(ast[3]) > 0)
            end
        elseif ast[1][1] == UN_OP then
            if ast[1][2] == "!" then
                local oldBool = interp_expr(ast[2])
                if oldBool > 0 then 
                    return 0
                else
                    return 1
                end
            elseif ast[1][2] == "+" then
                return interp_expr(ast[2])
            elseif ast[1][2] == "-" then
                return -interp_expr(ast[2])
            end
        end        
    end
    
    
    interp_stmt_list(ast)
    
    return state
end


-- ***** Module Export *****


return interpit

