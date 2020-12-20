-- parseit.lua
-- Mark Underwood
-- Based upon rdparser4.lua by Glenn G. Chappell
-- 15 Feb 2019
--
-- For CS F331 / CSCE A331 Spring 2019
-- Requires lexit.lua

local parseit = {}  -- Our module

local lexit = require "lexit"


-- Variables

-- For lexer iteration
local iter          -- Iterator returned by lexit.lex
local state         -- State for above iterator (maybe not used)
local lexer_out_s   -- Return value #1 from above iterator
local lexer_out_c   -- Return value #2 from above iterator

-- For current lexeme
local lexstr = ""   -- String form of current lexeme
local lexcat = 0    -- Category of current lexeme:
                    --  one of categories below, or 0 for past the end

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


-- Utility Functions

-- advance
-- Go to next lexeme and load it into lexstr, lexcat.
-- Should be called once before any parsing is done.
-- Function init must be called before this function is called.
local function advance()
    -- Advance the iterator
    lexer_out_s, lexer_out_c = iter(state, lexer_out_s)

    -- If we're not past the end, copy current lexeme into vars
    if lexer_out_s ~= nil then
        lexstr, lexcat = lexer_out_s, lexer_out_c
    else
        lexstr, lexcat = "", 0
    end
end


-- init
-- Initial call. Sets input for parsing functions.
local function init(prog)
    iter, state, lexer_out_s = lexit.lex(prog)
    advance()
end


-- atEnd
-- Return true if pos has reached end of input.
-- Function init must be called before this function is called.
local function atEnd()
    return lexcat == 0
end


-- matchString
-- Given string, see if current lexeme string form is equal to it. If
-- so, then advance to next lexeme & return true. If not, then do not
-- advance, return false.
-- Function init must be called before this function is called.
local function matchString(s)
    if lexstr == s then
        advance()
        return true
    else
        return false
    end
end


-- matchCat
-- Given lexeme category (integer), see if current lexeme category is
-- equal to it. If so, then advance to next lexeme & return true. If
-- not, then do not advance, return false.
-- Function init must be called before this function is called.
local function matchCat(c)
    if lexcat == c then
        advance()
        return true
    else
        return false
    end
end


-- Primary Function for Client Code

-- "local" statements for parsing functions
local parse_expr
local parse_term
local parse_factor

-- parse
-- Given program, initialize parser and call parsing function for start
-- symbol. Returns pair of booleans & AST. First boolean indicates
-- successful parse or not. Second boolean indicates whether the parser
-- reached the end of the input or not. AST is only valid if first
-- boolean is true.
function parseit.parse(prog)
    -- Initialization
    init(prog)

    -- Get results from parsing
    local good, ast = parse_program()
    local done = atEnd()

    -- And return them
    return good, done, ast
end


-- Parsing Functions

-- Each of the following is a parsing function for a nonterminal in the
-- grammar. Each function parses the nonterminal in its name and returns
-- a pair: boolean, AST. On a successul parse, the boolean is true, the
-- AST is valid, and the current lexeme is just past the end of the
-- string the nonterminal expanded into. Otherwise, the boolean is
-- false, the AST is not valid, and no guarantees are made about the
-- current lexeme. See the AST Specification near the beginning of this
-- file for the format of the returned AST.

-- NOTE. Declare parsing functions "local" above, but not below. This
-- allows them to be called before their definitions.

-- parse_program
-- Parsing function for nonterminal "program".
-- Function init must be called before this function is called.
function parse_program()
    local good, ast

    good, ast = parse_stmt_list()
    return good, ast
end

-- parse_stmt_list
-- Parsing function for nonterminal "stmt_list".
-- Function init must be called before this function is called.
function parse_stmt_list()
    local good, ast, newast

    ast = { STMT_LIST }
    while true do
        if lexstr ~= "write"
          and lexstr ~= "def"
          and lexstr ~= "if"
          and lexstr ~= "while"
          and lexstr ~= "return"
          and lexcat ~= lexit.ID then
            return true, ast
        end

        good, newast = parse_statement()
        if not good then
            return false, nil
        end

        table.insert(ast, newast)
    end
end

-- parse_statement
-- Parsing function for nonterminal "statement".
-- Function init must be called before this function is called.
function parse_statement()
    local good, ast1, ast2, savelex
    
    savelex = lexstr
    if matchString("write") then
        if not matchString("(") then
            return false, nil
        end

        good, ast1 = parse_write_arg()
        if not good then
            return false, nil
        end

        ast2 = { WRITE_STMT, ast1 }

        while matchString(",") do
            good, ast1 = parse_write_arg()
            if not good then
                return false, nil
            end

            table.insert(ast2, ast1)
        end

        if not matchString(")") then
            return false, nil
        end
    elseif matchString("def") then
        savelex = lexstr
        
        if matchCat(lexit.ID) then
            if matchString("(") then
                if not matchString(")") then
                    return false, nil
                end
                
                good, ast1 = parse_stmt_list()
                if not good or not matchString("end") then
                    return false, nil
                end
            else
                return false, nil
            end
            
            ast2 = {FUNC_DEF, savelex, ast1}
        else
            return false, nil
        end
    elseif matchString("while") then
        good, ast1 = parse_expr()
        if not good then
            return false, nil
        end
        
        ast2 = { WHILE_STMT, ast1 }
        
        good, ast1 = parse_stmt_list()
        if not good or not matchString("end") then 
            return false, nil
        end
        
        table.insert(ast2, ast1)
    elseif matchString("if") then
        ast2 = { IF_STMT}
        
        repeat
          good, ast1 = parse_expr()
          if not good then
              return false, nil
          end
          
          table.insert(ast2, ast1)
          
          good, ast1 = parse_stmt_list()
          if not good then 
              return false, nil
          end
        
          table.insert(ast2, ast1)
        until not matchString("elseif")
        
        if matchString("else") then
            good, ast1 = parse_stmt_list()
            if not good then 
                return false, nil
            end
            
            table.insert(ast2, ast1)
        end
        
        if not matchString("end") then
            return false, nil
        end
    elseif matchString("return") then
        good, ast1 = parse_expr()
        if not good then
            return false, nil
        end
        
        ast2 = { RETURN_STMT, ast1 }
    elseif matchCat(lexit.ID) then
        ast2 = { ASSN_STMT }
        
        if matchString("(") then
            if not matchString(")") then
                return false, nil
            end
            ast2 = { FUNC_CALL, savelex }
            return true, ast2
        elseif matchString("[") then
            good, ast1 = parse_expr()
            if not good then
                return false, nil
            end
            
            table.insert(ast2, { ARRAY_VAR, savelex, ast1 })
            
            if not matchString("]") then
                return false, nil
            end
        else
            table.insert(ast2, { SIMPLE_VAR, savelex })
        end
        
        if matchString("=") then
            good, ast1 = parse_expr()
            if not good then
                return false, nil
            end
          
            table.insert(ast2, ast1)
        else
            return false, nil
        end
    end
    
    return true, ast2
end

-- parse_expr
-- Parsing function for nonterminal "expr".
-- Function init must be called before this function is called.
function parse_expr()
    local good, ast, saveop, newast

    good, ast = parse_comp_expr()
    if not good then
        return false, nil
    end

    while true do
        saveop = lexstr
        if not matchString("&&") and not matchString("||") then
            break
        end

        good, newast = parse_comp_expr()
        if not good then
            return false, nil
        end

        ast = { { BIN_OP, saveop }, ast, newast }
    end

    return true, ast
end

-- parse_comp_expr
-- Parsing function for nonterminal "comp_expr".
-- Function init must be called before this function is called.
function parse_comp_expr()
    local good, ast, saveop, newast
    
    if matchString("!") then
        good, ast = parse_comp_expr()
        if not good then 
            return false, nil
        end
        
        ast = { { UN_OP, "!" }, ast }
    else
        good, ast = parse_arith_expr()
        if not good then 
            return false, nil
        end
        
        while true do
            saveop = lexstr
            if not (matchString("==") 
               or  matchString("!=") 
               or  matchString("<") 
               or  matchString(">") 
               or  matchString("<=") 
               or  matchString(">=")) then
                break
            end
            
            good, newast = parse_arith_expr()
            if not good then 
                return false, nil
            end
            
            ast = { { BIN_OP, saveop }, ast, newast }
        end
        
    end
    
    return true, ast
end

-- parse_arith_expr
-- Parsing function for nonterminal "arith_expr".
-- Function init must be called before this function is called.
function parse_arith_expr()
    local good, ast, saveop, newast
  
    good, ast = parse_term()
    if not good then
        return false, nil
    end

    while true do
        saveop = lexstr
        if not matchString("+") and not matchString("-") then
            break
        end

        good, newast = parse_term()
        if not good then
            return false, nil
        end

        ast = { { BIN_OP, saveop }, ast, newast }
    end
    
    return true, ast
end

-- parse_term
-- Parsing function for nonterminal "term".
-- Function init must be called before this function is called.
function parse_term()
    local good, ast, saveop, newast

    good, ast = parse_factor()
    if not good then
        return false, nil
    end

    while true do
        saveop = lexstr
        if not matchString("*") and not matchString("/") and not matchString("%") then
            break
        end

        good, newast = parse_factor()
        if not good then
            return false, nil
        end

        ast = { { BIN_OP, saveop }, ast, newast }
    end

    return true, ast
end


-- parse_factor
-- Parsing function for nonterminal "factor".
-- Function init must be called before this function is called.
function parse_factor()
    local savelex, good, ast

    savelex = lexstr
    if matchCat(lexit.ID) then
        if matchString("(") then
            if not matchString(")") then
                return false, nil
            end
            ast = { FUNC_CALL, savelex }
        elseif matchString("[") then
            good, ast = parse_expr()
            if not good then
                return false, nil
            end
            
            if not matchString("]") then
                return false, nil
            end
            
            ast = { ARRAY_VAR, savelex, ast }
        else
            ast = { SIMPLE_VAR, savelex }
        end
    elseif matchCat(lexit.NUMLIT) then
        ast = { NUMLIT_VAL, savelex }
    elseif matchString("(") then
        good, ast = parse_expr()
        if not good then
            return false, nil
        end

        if not matchString(")") then
            return false, nil
        end
    elseif matchString("true") or matchString("false") then
        ast = { BOOLLIT_VAL, savelex }
    elseif matchString("+") or matchString("-") then
        good, ast = parse_factor()
        if not good then
            return false, nil
        end
        
        ast = { { UN_OP, savelex }, ast }
    elseif matchString("readnum") then
        if not matchString("(") then
            return false, nil
        end  
        if not matchString(")") then
            return false, nil
        end
        
        ast = { READNUM_CALL }
    else
        return false, nil
    end
    return true, ast
end

-- parse_write_arg
-- Parsing function for nonterminal "write_arg".
-- Function init must be called before this function is called.
function parse_write_arg()
    local savelex, good, ast
    savelex = lexstr
    
    if matchString("cr") then
        ast = { CR_OUT }
    elseif matchCat(lexit.STRLIT) then
        ast = { STRLIT_OUT, savelex }
    else
        good, ast = parse_expr()
        if not good then
            return false, nil
        end
    end
    return true, ast
end



-- Module Export

return parseit

