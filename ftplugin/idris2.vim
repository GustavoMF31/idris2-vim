if bufname('%') == "idris-response"
  finish
endif

if exists("b:did_ftplugin")
  finish
endif

setlocal shiftwidth=2
setlocal tabstop=2
if !exists("g:idris_allow_tabchar") || g:idris_allow_tabchar == 0
	setlocal expandtab
endif
setlocal comments=s1:{-,mb:-,ex:-},:\|\|\|,:--
setlocal commentstring=--%s
setlocal iskeyword+=?
setlocal wildignore+=*.ibc

let idris_response = 0
let b:did_ftplugin = 1

" Text near cursor position that needs to be passed to a command.
" Refinment of `expand(<cword>)` to accomodate differences between
" a (n)vim word and what Idris requires.
function! s:currentQueryObject()
  let word = expand("<cword>")
  if word =~ '^?'
    " Cut off '?' that introduces a hole identifier.
    let word = strpart(word, 1)
  endif
  return word
endfunction

function! s:IdrisCommand(...)
  let idriscmd = shellescape(join(a:000))

  " write the file so that Idris2 can interact with it
  w

  " Vim does not support ANSI escape codes natively, so we need to disable
  " automatic colouring
  let commandResult =  system("idris2 --no-color --find-ipkg " . shellescape(expand('%:p')) . " --client " . idriscmd)

  " Keep the window in the same place when reading the file
  let save_view = winsaveview()

  " update the file (Idris2 may have modified it)
  e

  call winrestview(save_view)

  return commandResult
endfunction

function! IdrisDocFold(lineNum)
  let line = getline(a:lineNum)

  if line =~ "^\s*|||"
    return "1"
  endif

  return "0"
endfunction

function! IdrisFold(lineNum)
  return IdrisDocFold(a:lineNum)
endfunction

setlocal foldmethod=expr
setlocal foldexpr=IdrisFold(v:lnum)

" Checks if the idris-response buffer is visible in the current tab
function! s:IsResposeWinVisible()
  return index(tabpagebuflist(), bufnr("idris-response")) >= 0
endfunction

function! IdrisResponseWin()
  if !s:IsResposeWinVisible()
    " Create the idris-response buffer if it isn't visible.
    botright 10split
    badd idris-response
    b idris-response
    set buftype=nofile
    wincmd k

  else
    " Close it otherwise, but just in the current tab
    let winnr = bufwinnr("idris-response")
    execute winnr . "wincmd c"
  endif
endfunction

function! IWrite(str)
  if s:IsResposeWinVisible()
    " Save the cursor and scroll position (as well as some other details)
    let save_view = winsaveview()

    " Save the user's 'hidden' option so that we can temporarily set it on in
    " order to preserve the undo history when switching buffers
    let save_hidden = &hidden

    set hidden
    b idris-response
    %delete
    let resp = split(a:str, '\n')
    call append(1, resp)
    b #

    " Restore the saved values
    let &hidden = save_hidden
    call winrestview(save_view)
  else
    echo a:str
  endif
endfunction

function! IdrisReload(q)
  let file = expand('%:p')

  let tc = s:IdrisCommand('')

  if (! (tc is ""))
    call IWrite(tc)
  else
    if (a:q==0)
       call IWrite("Successfully reloaded " . file)
    endif
  endif
  return tc
endfunction

function! IdrisReloadToLine(cline)
  return IdrisReload(1)
  "w
  "let file = expand("%:p")
  "let tc = s:IdrisCommand(":lto", a:cline, file)
  "if (! (tc is ""))
  "  call IWrite(tc)
  "endif
  "return tc
endfunction

function! IdrisShowType()
  let word = s:currentQueryObject()
  let cline = line(".")
  let ccol = col(".")
    let ty = s:IdrisCommand(":t", word)
    call IWrite(ty)
endfunction

function! IdrisShowDoc()
  let word = expand("<cword>")
  let ty = s:IdrisCommand(":doc", word)
  call IWrite(ty)
endfunction

function! IdrisProofSearch(hint)
  let cline = line(".")
  let word = s:currentQueryObject()

  if (a:hint==0)
     let hints = ""
  else
     let hints = input ("Hints: ")
  endif

  let result = s:IdrisCommand(":ps!", cline, word, hints)
  if (! (result is ""))
     call IWrite(result)
  endif
endfunction

function! IdrisGenerateDef()
  let cline = line(".")
  let word = s:currentQueryObject()

  let result = s:IdrisCommand(":gd!", cline, word)
  if (! (result is ""))
     call IWrite(result)
  endif
endfunction

function! IdrisMakeLemma()
  let cline = line(".")
  let word = s:currentQueryObject()

  let result = s:IdrisCommand(":ml!", cline, word)
  if (! (result is ""))
     call IWrite(result)
  else
    " Search backwards for the word the cursor was on
    call search(word, "b")
  endif
endfunction

function! IdrisRefine()
  let cline = line(".")
  let word = expand("<cword>")
  let name = input ("Name: ")

  let result = s:IdrisCommand(":ref!", cline, word, name)
  if (! (result is ""))
     call IWrite(result)
  endif
endfunction

function! IdrisAddMissing()
  let cline = line(".")
  let word = expand("<cword>")

  let result = s:IdrisCommand(":am!", cline, word)
  if (! (result is ""))
     call IWrite(result)
  endif
endfunction

function! IdrisCaseSplit()
  let cline = line(".")
  let ccol = col(".")
  let word = expand("<cword>")
  let result = s:IdrisCommand(":cs!", cline, ccol, word)
  if (! (result is ""))
     call IWrite(result)
  endif
endfunction

function! IdrisMakeWith()
  let cline = line(".")
  let word = s:currentQueryObject()

  " Why is reload needed here?
  " let tc = IdrisReload(1)

  let result = s:IdrisCommand(":mw!", cline, word)
  if (! (result is ""))
     call IWrite(result)
  else
    " Got to the underscore the command creates
    call search("_")
  endif
endfunction

function! IdrisMakeCase()
  let cline = line(".")
  let word = s:currentQueryObject()

  let result = s:IdrisCommand(":mc!", cline, word)
  if (! (result is ""))
     call IWrite(result)
  else
    call search("_")
  endif
endfunction

function! IdrisAddClause(proof)
  let cline = line(".")
  let word = expand("<cword>")

  if (a:proof==0)
    let fn = ":ac!"
  else
    let fn = ":apc!"
  endif

  let result = s:IdrisCommand(fn, cline, word)
  if (! (result is ""))
     call IWrite(result)
  else
    call search(word)
  endif
endfunction

function! IdrisTypeAt()
  let cline = line(".")
  let ccol = col(".")

  let name = s:currentQueryObject()

  let result = s:IdrisCommand(":typeat", cline, ccol, name)

  if (! (result is ""))
     call IWrite(result)
  endif
endfunction

function! IdrisEval()
  let expr = input ("Expression: ")
  let result = s:IdrisCommand(expr)
  call IWrite(" = " . result)
endfunction

nnoremap <buffer> <silent> <LocalLeader>t :call IdrisShowType()<ENTER>
nnoremap <buffer> <silent> <LocalLeader>r :call IdrisReload(0)<ENTER>
nnoremap <buffer> <silent> <LocalLeader>c :call IdrisCaseSplit()<ENTER>
nnoremap <buffer> <silent> <LocalLeader>a 0:call search(":")<ENTER>b:call IdrisAddClause(0)<ENTER>w
nnoremap <buffer> <silent> <LocalLeader>d 0:call search(":")<ENTER>b:call IdrisAddClause(0)<ENTER>w
nnoremap <buffer> <silent> <LocalLeader>b 0:call IdrisAddClause(0)<ENTER>
nnoremap <buffer> <silent> <LocalLeader>m :call IdrisAddMissing()<ENTER>
nnoremap <buffer> <silent> <LocalLeader>md 0:call search(":")<ENTER>b:call IdrisAddClause(1)<ENTER>w
nnoremap <buffer> <silent> <LocalLeader>f :call IdrisRefine()<ENTER>
nnoremap <buffer> <silent> <LocalLeader>o :call IdrisProofSearch(0)<ENTER>
nnoremap <buffer> <silent> <LocalLeader>s :call IdrisProofSearch(0)<ENTER>
nnoremap <buffer> <silent> <LocalLeader>g :call IdrisGenerateDef()<ENTER>
nnoremap <buffer> <silent> <LocalLeader>p :call IdrisProofSearch(1)<ENTER>
nnoremap <buffer> <silent> <LocalLeader>l :call IdrisMakeLemma()<ENTER>
nnoremap <buffer> <silent> <LocalLeader>e :call IdrisEval()<ENTER>
nnoremap <buffer> <silent> <LocalLeader>w 0:call IdrisMakeWith()<ENTER>
nnoremap <buffer> <silent> <LocalLeader>mc :call IdrisMakeCase()<ENTER>
nnoremap <buffer> <silent> <LocalLeader>i 0:call IdrisResponseWin()<ENTER>
nnoremap <buffer> <silent> <LocalLeader>h :call IdrisShowDoc()<ENTER>
nnoremap <buffer> <silent> <LocalLeader>y :call IdrisTypeAt()<ENTER>

menu Idris.Reload <LocalLeader>r
menu Idris.Show\ Type <LocalLeader>t
menu Idris.Evaluate <LocalLeader>e
menu Idris.-SEP0- :
menu Idris.Add\ Clause <LocalLeader>a
menu Idris.Generate\ Definition <LocalLeader>g
menu Idris.Add\ with <LocalLeader>w
menu Idris.Case\ Split <LocalLeader>c
menu Idris.Add\ missing\ cases <LocalLeader>m
menu Idris.Proof\ Search <LocalLeader>s
menu Idris.Proof\ Search\ with\ hints <LocalLeader>p
