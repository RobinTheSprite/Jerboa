--lexit.lua
--Mark Underwood
--2/17/2019
--Based upon lexer.lua by Dr. Glenn Chappell
--performs lexical analysis for Jerboa programming language

local lexit = {}


  lexit.KEY       = 1
  lexit.ID        = 2
  lexit.NUMLIT    = 3
  lexit.STRLIT    = 4
  lexit.OP        = 5
  lexit.PUNCT     = 6
  lexit.MAL       = 7


  lexit.catnames = {
      "Keyword",
      "Identifier",
      "NumericLiteral",
      "StringLiteral",
      "Operator",
      "Punctuation",
      "Malformed"
  }

  local keywords = {
      cr = true,
      def = true,
      ["else"] = true,
      ["elseif"] = true,
      ["end"] = true,
      ["false"] = true,
      ["if"] = true,
      readnum = true,
      ["return"] = true,
      ["true"] = true,
      ["while"] = true,
      write = true
  }

  local operators = {
      ["*"] = true,
      ["&"] = true,
      ["%"] = true,
      ["!"] = true,
      ["/"] = true,
      ["["] = true,
      ["]"] = true,
      ["<"] = true,
      [">"] = true,
      ["|"] = true,
      ["+"] = true,
      ["-"] = true,
      ["="] = true,
  }

  local doubleOperators = {
      ["&&"] = true,
      ["!="] = true,
      ["<="] = true,
      [">="] = true,
      ["||"] = true,
      ["=="] = true,
  }

-- isLetter
-- Returns true if string c is a letter character, false otherwise.
local function isLetter(c)
    if c:len() ~= 1 then
        return false
    elseif c >= "A" and c <= "Z" then
        return true
    elseif c >= "a" and c <= "z" then
        return true
    else
        return false
    end
end

-- isDigit
-- Returns true if string c is a digit character, false otherwise.
local function isDigit(c)
    if c:len() ~= 1 then
        return false
    elseif c >= "0" and c <= "9" then
        return true
    else
        return false
    end
end

-- isWhitespace
-- Returns true if string c is a whitespace character, false otherwise.
local function isWhitespace(c)
    if c:len() ~= 1 then
        return false
    elseif c == " " or c == "\t" or c == "\n" or c == "\r"
      or c == "\f" then
        return true
    else
        return false
    end
end

-- isIllegal
-- Returns true if string c is an illegal character, false otherwise.
local function isIllegal(c)
    if c:len() ~= 1 then
        return false
    elseif isWhitespace(c) then
        return false
    elseif c >= " " and c <= "~" then
        return false
    else
        return true
    end
end

function lexit.lex(program)
  -- ***** Variables (like class data members) *****

  local pos       -- Index of next character in program
                  -- INVARIANT: when getLexeme is called, pos is
                  --  EITHER the index of the first character of the
                  --  next lexeme OR program:len()+1
  local state     -- Current state for our state machine
  local ch        -- Current character
  local lexstr    -- The lexeme, so far
  local category  -- Category of lexeme, set when state set to DONE
  local handlers  -- Dispatch table; value created later
  
  local quote               --Either a single or a double quote, depending on the string
  local lastLexemeCategory  --The last lexeme to be parsed and its category
  local lastLexeme          --
  
    -- ***** Character-Related Utility Functions *****

  -- currChar
  -- Return the current character, at index pos in program. Return
  -- value is a single-character string, or the empty string if pos is
  -- past the end.
  local function currChar()
      return program:sub(pos, pos)
  end

  -- nextChar
  -- Return the next character, at index pos+1 in program. Return
  -- value is a single-character string, or the empty string if pos+1
  -- is past the end.
  local function nextChar()
      return program:sub(pos+1, pos+1)
  end
  
  --lastChar
  --Return the last character in the string, or the empty string if 
  --pos-1 is before the first character
  local function lastChar()
      return program:sub(pos-1, pos-1)
  end
  
  --lookahead2
  --Return the character after next in the string, or the empty string if pos+2 is past the end
  local function lookahead2()
      return program:sub(pos+2, pos+2)
  end

  -- drop1
  -- Move pos to the next character.
  local function drop1()
      pos = pos+1
  end

  -- add1
  -- Add the current character to the lexeme, moving pos to the next
  -- character.
  local function add1()
      lexstr = lexstr .. currChar()
      drop1()
  end

  -- skipWhitespace
  -- Skip whitespace and comments, moving pos to the beginning of
  -- the next lexeme, or to program:len()+1.
  local function skipWhitespace()
      while true do      -- In whitespace
          while isWhitespace(currChar()) do
              drop1()
          end

          if currChar() ~= "#" then  -- Comment?
              break
          end
          drop1()

          while true do  -- In comment
              if currChar() == "\n" then
                  drop1()
                  break
              elseif currChar() == "" then  -- End of input?
                 return
              end
              drop1()
          end
      end
  end

  -- ***** State-Handler Functions *****

  -- A function with a name like handle_XYZ is the handler function
  -- for state XYZ

  local function handle_DONE()
      io.write("ERROR: 'DONE' state should not be handled\n")
      assert(0)
  end

  local function handle_START()
      if isIllegal(ch) then
          add1()
          state = handlers.DONE
          category = lexit.MAL
      elseif isLetter(ch) or ch == "_" then
          add1()
          state = handlers.LETTER
      elseif isDigit(ch) then
          add1()
          state = handlers.DIGIT
      elseif ch == "+" then
          state = handlers.PLUSMINUS
      elseif ch == "-" then
          state = handlers.PLUSMINUS
      elseif operators[ch] then
          add1()
          state = handlers.OPERATOR
      elseif ch == "'" or ch == [["]] then
          delimiter = ch
          add1()
          state = handlers.STRING
      else
          add1()
          state = handlers.DONE
          category = lexit.PUNCT
      end
  end

  local function handle_LETTER()
      if isLetter(ch) or isDigit(ch) or ch == "_" then
          add1()
      else
          state = handlers.DONE
          if keywords[lexstr] then
              category = lexit.KEY
          else
              category = lexit.ID
          end
      end
  end

  local function handle_DIGIT()
      if isDigit(ch) then
          add1()
      elseif ch == "e" or ch == "E" then
          if isDigit(nextChar()) or (nextChar() == "+" and isDigit(lookahead2())) then
            add1()
            add1()
            state = handlers.EXP
          else
            state = handlers.DONE
            category = lexit.NUMLIT
          end
      else
          state = handlers.DONE
          category = lexit.NUMLIT
      end
  end

  local function handle_EXP()
      if isDigit(ch) then
          add1()
      else
          state = handlers.DONE
          category = lexit.NUMLIT
      end
  end

  local function handle_PLUSMINUS()
      if lastLexemeCategory == lexit.ID or lastLexemeCategory == lexit.NUMLIT 
         or lastLexeme == "]" or lastLexeme == ")" or lastLexeme == "true" or lastLexeme == "false" then
          state = handlers.DONE
          category = lexit.OP
      elseif (isDigit(nextChar()) and not (lastChar() == "e" or lastChar() == "E"))
        or (lastLexemeCategory == lexit.KEY and (lastChar() == "e" or lastChar() == "E")) then
          state = handlers.DIGIT
      else          
          state = handlers.DONE
          category = lexit.OP
      end
      
      add1()
  end

  local function handle_OPERATOR()
      if operators[ch] and doubleOperators[lastChar()..ch] then
          add1()
          state = handlers.DONE
          category = lexit.OP
      elseif lastChar() ~= "&" and lastChar() ~= "|" then
          state = handlers.DONE
          category = lexit.OP
      else
          state = handlers.DONE
          category = lexit.PUNCT
      end
  end
  
  local function handle_STRING()
      
      if ch == delimiter then
          state = handlers.DONE
          category = lexit.STRLIT
      elseif ch == "\n" or ch == "" then
          state = handlers.DONE
          category = lexit.MAL
      end
      add1()
  end

  -- ***** Table of State-Handler Functions *****

  handlers = {
      DONE       = handle_DONE,
      START      = handle_START,
      LETTER     = handle_LETTER,
      DIGIT      = handle_DIGIT,
      EXP        = handle_EXP,
      DOT        = handle_DOT,
      PLUSMINUS  = handle_PLUSMINUS,
      MINUS      = handle_MINUS,
      OPERATOR   = handle_OPERATOR,
      STRING     = handle_STRING
  }

  -- ***** Iterator Function *****

  -- getLexeme
  -- Called each time through the for-in loop.
  -- Returns a pair: lexeme-string (string) and category (int), or
  -- nil, nil if no more lexemes.
  local function getLexeme(dummy1, dummy2)
      if pos > program:len() then
          return nil, nil
      end
      lexstr = ""
      state = handlers.START
      while state ~= handlers.DONE do
          ch = currChar()
          state()
      end

      skipWhitespace()
      lastLexemeCategory = category
      lastLexeme = lexstr
      return lexstr, category
  end

  -- ***** Body of Function lex *****

  -- Initialize & return the iterator function
  pos = 1
  skipWhitespace()
  return getLexeme, nil, nil
end

return lexit