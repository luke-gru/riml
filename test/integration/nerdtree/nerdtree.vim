if exists("g:loaded_nerdtree_autoload")
  finish
endif
let g:loaded_nerdtree_autoload = 1
function! nerdtree#version()
  return '4.2.0'
endfunction
function! nerdtree#bufInWindows(bnum)
  let cnt = 0
  let winnum = 1
  while 1
    let bufnum = winbufnr(winnum)
    if bufnum <# 0
      break
    endif
    if bufnum ==# a:bnum
      let cnt = cnt + 1
    endif
    let winnum = winnum + 1
  endwhile
  return cnt
endfunction
function! nerdtree#checkForBrowse(dir)
  if a:dir !=# '' && isdirectory(a:dir)
    call g:NERDTreeCreator.CreateSecondary(a:dir)
  endif
endfunction
function! nerdtree#completeBookmarks(A, L, P)
  return filter(g:NERDTreeBookmark.BookmarkNames(), 'v:val =~# "^' . a:A . '"')
endfunction
function! nerdtree#compareBookmarks(first, second)
  return a:first.compareTo(a:second)
endfunction
function! nerdtree#compareNodes(n1, n2)
  return a:n1.path.compareTo(a:n2.path)
endfunction
function! nerdtree#createDefaultBindings()
  let s = '<SNR>' . s:SID() . '_'
  call s:NERDTreeAddKeyMap({'key': '<MiddleRelease>', 'scope': "all", 'callback': s . "handleMiddleMouse"})
  call s:NERDTreeAddKeyMap({'key': '<LeftRelease>', 'scope': "all", 'callback': s . "handleLeftClick"})
  call s:NERDTreeAddKeyMap({'key': '<2-LeftMouse>', 'scope': "DirNode", 'callback': s . "activateDirNode"})
  call s:NERDTreeAddKeyMap({'key': '<2-LeftMouse>', 'scope': "FileNode", 'callback': s . "activateFileNode"})
  call s:NERDTreeAddKeyMap({'key': '<2-LeftMouse>', 'scope': "Bookmark", 'callback': s . "activateBookmark"})
  call s:NERDTreeAddKeyMap({'key': '<2-LeftMouse>', 'scope': "all", 'callback': s . "activateAll"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapActivateNode, 'scope': "DirNode", 'callback': s . "activateDirNode"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapActivateNode, 'scope': "FileNode", 'callback': s . "activateFileNode"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapActivateNode, 'scope': "Bookmark", 'callback': s . "activateBookmark"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapActivateNode, 'scope': "all", 'callback': s . "activateAll"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapOpenSplit, 'scope': "Node", 'callback': s . "openHSplit"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapOpenVSplit, 'scope': "Node", 'callback': s . "openVSplit"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapOpenSplit, 'scope': "Bookmark", 'callback': s . "openHSplit"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapOpenVSplit, 'scope': "Bookmark", 'callback': s . "openVSplit"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapPreview, 'scope': "Node", 'callback': s . "previewNodeCurrent"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapPreviewVSplit, 'scope': "Node", 'callback': s . "previewNodeVSplit"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapPreviewSplit, 'scope': "Node", 'callback': s . "previewNodeHSplit"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapPreview, 'scope': "Bookmark", 'callback': s . "previewNodeCurrent"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapPreviewVSplit, 'scope': "Bookmark", 'callback': s . "previewNodeVSplit"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapPreviewSplit, 'scope': "Bookmark", 'callback': s . "previewNodeHSplit"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapOpenRecursively, 'scope': "DirNode", 'callback': s . "openNodeRecursively"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapUpdir, 'scope': "all", 'callback': s . "upDirCurrentRootClosed"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapUpdirKeepOpen, 'scope': "all", 'callback': s . "upDirCurrentRootOpen"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapChangeRoot, 'scope': "Node", 'callback': s . "chRoot"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapChdir, 'scope': "Node", 'callback': s . "chCwd"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapQuit, 'scope': "all", 'callback': s . "closeTreeWindow"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapCWD, 'scope': "all", 'callback': "nerdtree#chRootCwd"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapRefreshRoot, 'scope': "all", 'callback': s . "refreshRoot"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapRefresh, 'scope': "Node", 'callback': s . "refreshCurrent"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapHelp, 'scope': "all", 'callback': s . "displayHelp"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapToggleZoom, 'scope': "all", 'callback': s . "toggleZoom"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapToggleHidden, 'scope': "all", 'callback': s . "toggleShowHidden"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapToggleFilters, 'scope': "all", 'callback': s . "toggleIgnoreFilter"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapToggleFiles, 'scope': "all", 'callback': s . "toggleShowFiles"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapToggleBookmarks, 'scope': "all", 'callback': s . "toggleShowBookmarks"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapCloseDir, 'scope': "Node", 'callback': s . "closeCurrentDir"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapCloseChildren, 'scope': "DirNode", 'callback': s . "closeChildren"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapMenu, 'scope': "Node", 'callback': s . "showMenu"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapJumpParent, 'scope': "Node", 'callback': s . "jumpToParent"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapJumpFirstChild, 'scope': "Node", 'callback': s . "jumpToFirstChild"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapJumpLastChild, 'scope': "Node", 'callback': s . "jumpToLastChild"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapJumpRoot, 'scope': "all", 'callback': s . "jumpToRoot"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapJumpNextSibling, 'scope': "Node", 'callback': s . "jumpToNextSibling"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapJumpPrevSibling, 'scope': "Node", 'callback': s . "jumpToPrevSibling"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapOpenInTab, 'scope': "Node", 'callback': s . "openInNewTab"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapOpenInTabSilent, 'scope': "Node", 'callback': s . "openInNewTabSilent"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapOpenInTab, 'scope': "Bookmark", 'callback': s . "openInNewTab"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapOpenInTabSilent, 'scope': "Bookmark", 'callback': s . "openInNewTabSilent"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapOpenExpl, 'scope': "DirNode", 'callback': s . "openExplorer"})
  call s:NERDTreeAddKeyMap({'key': g:NERDTreeMapDeleteBookmark, 'scope': "Bookmark", 'callback': s . "deleteBookmark"})
endfunction
function! nerdtree#deprecated(func, ...)
  let msg = a:0 ? a:func . ' ' . a:1 : a:func . ' is deprecated'
  if !exists('s:deprecationWarnings')
    let s:deprecationWarnings = {}
  endif
  if !has_key(s:deprecationWarnings, a:func)
    let s:deprecationWarnings[a:func] = 1
    echomsg msg
  endif
endfunction
function! nerdtree#escChars()
  if nerdtree#runningWindows()
    return " `\|\"#%&,?()\*^<>"
  endif
  return " \\`\|\"#%&,?()\*^<>[]"
endfunction
function! nerdtree#exec(cmd)
  let old_ei = &ei
  set ei=all
  exec a:cmd
  let &ei = old_ei
endfunction
function! nerdtree#findAndRevealPath()
  try
    let p = g:NERDTreePath.New(expand("%:p"))
  catch /^NERDTree.InvalidArgumentsError/
    call nerdtree#echo("no file for the current buffer")
    return
  endtry
  if p.isUnixHiddenPath()
    let showhidden = g:NERDTreeShowHidden
    let g:NERDTreeShowHidden = 1
  endif
  if !nerdtree#treeExistsForTab()
    try
      let cwd = g:NERDTreePath.New(getcwd())
    catch /^NERDTree.InvalidArgumentsError/
      call nerdtree#echo("current directory does not exist.")
      let cwd = p.getParent()
    endtry
    if p.isUnder(cwd)
      call g:NERDTreeCreator.CreatePrimary(cwd.str())
    else
      call g:NERDTreeCreator.CreatePrimary(p.getParent().str())
    endif
  else
    if !p.isUnder(g:NERDTreeFileNode.GetRootForTab().path)
      if !nerdtree#isTreeOpen()
        call g:NERDTreeCreator.TogglePrimary('')
      else
        call nerdtree#putCursorInTreeWin()
      endif
      let b:NERDTreeShowHidden = g:NERDTreeShowHidden
      call nerdtree#chRoot(g:NERDTreeDirNode.New(p.getParent()))
    else
      if !nerdtree#isTreeOpen()
        call g:NERDTreeCreator.TogglePrimary("")
      endif
    endif
  endif
  call nerdtree#putCursorInTreeWin()
  call b:NERDTreeRoot.reveal(p)
  if p.isUnixHiddenFile()
    let g:NERDTreeShowHidden = showhidden
  endif
endfunction
function! nerdtree#has_opt(options, name)
  return has_key(a:options, a:name) && a:options[a:name] ==# 1
endfunction
function! nerdtree#invokeKeyMap(key)
  call g:NERDTreeKeyMap.Invoke(a:key)
endfunction
function! nerdtree#loadClassFiles()
  runtime lib/nerdtree/path.vim
  runtime lib/nerdtree/menu_controller.vim
  runtime lib/nerdtree/menu_item.vim
  runtime lib/nerdtree/key_map.vim
  runtime lib/nerdtree/bookmark.vim
  runtime lib/nerdtree/tree_file_node.vim
  runtime lib/nerdtree/tree_dir_node.vim
  runtime lib/nerdtree/opener.vim
  runtime lib/nerdtree/creator.vim
endfunction
function! nerdtree#postSourceActions()
  call g:NERDTreeBookmark.CacheBookmarks(0)
  call nerdtree#createDefaultBindings()
  runtime! nerdtree_plugin/**/*.vim
endfunction
function! nerdtree#runningWindows()
  return has("win16") || has("win32") || has("win64")
endfunction
function! s:SID()
  if !exists("s:sid")
    let s:sid = matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
  endif
  return s:sid
endfunction
function! nerdtree#tabpagevar(tabnr, var)
  let currentTab = tabpagenr()
  let old_ei = &ei
  set ei=all
  exec "tabnext " . a:tabnr
  let v = -1
  if exists('t:' . a:var)
    exec 'let v = t:' . a:var
  endif
  exec "tabnext " . currentTab
  let &ei = old_ei
  return v
endfunction
function! nerdtree#treeExistsForBuf()
  return exists("b:NERDTreeRoot")
endfunction
function! nerdtree#treeExistsForTab()
  return exists("t:NERDTreeBufName")
endfunction
function! nerdtree#treeMarkupReg()
  if g:NERDTreeDirArrows
    return '^\([▾▸] \| \+[▾▸] \| \+\)'
  endif
  return '^[ `|]*[\-+~]'
endfunction
function! nerdtree#treeUpDirLine()
  return '.. (up a dir)'
endfunction
function! nerdtree#treeWid()
  return 2
endfunction
function! nerdtree#upDir(keepState)
  let cwd = b:NERDTreeRoot.path.str({'format': 'UI'})
  if cwd ==# "/" || cwd =~# '^[^/]..$'
    call nerdtree#echo("already at top dir")
  else
    if !a:keepState
      call b:NERDTreeRoot.close()
    endif
    let oldRoot = b:NERDTreeRoot
    if empty(b:NERDTreeRoot.parent)
      let path = b:NERDTreeRoot.path.getParent()
      let newRoot = g:NERDTreeDirNode.New(path)
      call newRoot.open()
      call newRoot.transplantChild(b:NERDTreeRoot)
      let b:NERDTreeRoot = newRoot
    else
      let b:NERDTreeRoot = b:NERDTreeRoot.parent
    endif
    if g:NERDTreeChDirMode ==# 2
      call b:NERDTreeRoot.path.changeToDir()
    endif
    call nerdtree#renderView()
    call oldRoot.putCursorHere(0, 0)
  endif
endfunction
function! nerdtree#unique(list)
  let uniqlist = []
  for elem in a:list
    if index(uniqlist, elem) ==# -1
      let uniqlist += [elem]
    endif
  endfor
  return uniqlist
endfunction
function! nerdtree#centerView()
  if g:NERDTreeAutoCenter
    let current_line = winline()
    let lines_to_top = current_line
    let lines_to_bottom = winheight(nerdtree#getTreeWinNum()) - current_line
    if lines_to_top <# g:NERDTreeAutoCenterThreshold || lines_to_bottom <# g:NERDTreeAutoCenterThreshold
      normal! zz
    endif
  endif
endfunction
function! nerdtree#chRoot(node)
  call s:chRoot(a:node)
endfunction
function! nerdtree#closeTree()
  if !nerdtree#isTreeOpen()
    throw "NERDTree.NoTreeFoundError: no NERDTree is open"
  endif
  if winnr("$") !=# 1
    if winnr() ==# nerdtree#getTreeWinNum()
      call nerdtree#exec("wincmd p")
      let bufnr = bufnr("")
      call nerdtree#exec("wincmd p")
    else
      let bufnr = bufnr("")
    endif
    call nerdtree#exec(nerdtree#getTreeWinNum() . " wincmd w")
    close
    call nerdtree#exec(bufwinnr(bufnr) . " wincmd w")
  else
    close
  endif
endfunction
function! nerdtree#closeTreeIfOpen()
  if nerdtree#isTreeOpen()
    call nerdtree#closeTree()
  endif
endfunction
function! nerdtree#closeTreeIfQuitOnOpen()
  if g:NERDTreeQuitOnOpen && nerdtree#isTreeOpen()
    call nerdtree#closeTree()
  endif
endfunction
function! nerdtree#dumpHelp()
  let old_h = @h
  if b:treeShowHelp ==# 1
    let @h = "\" NERD tree (" . nerdtree#version() . ") quickhelp~\n"
    let @h = @h . "\" ============================\n"
    let @h = @h . "\" File node mappings~\n"
    let @h = @h . "\" " . (g:NERDTreeMouseMode ==# 3 ? "single" : "double") . "-click,\n"
    let @h = @h . "\" <CR>,\n"
    if b:NERDTreeType ==# "primary"
      let @h = @h . "\" " . g:NERDTreeMapActivateNode . ": open in prev window\n"
    else
      let @h = @h . "\" " . g:NERDTreeMapActivateNode . ": open in current window\n"
    endif
    if b:NERDTreeType ==# "primary"
      let @h = @h . "\" " . g:NERDTreeMapPreview . ": preview\n"
    endif
    let @h = @h . "\" " . g:NERDTreeMapOpenInTab . ": open in new tab\n"
    let @h = @h . "\" " . g:NERDTreeMapOpenInTabSilent . ": open in new tab silently\n"
    let @h = @h . "\" middle-click,\n"
    let @h = @h . "\" " . g:NERDTreeMapOpenSplit . ": open split\n"
    let @h = @h . "\" " . g:NERDTreeMapPreviewSplit . ": preview split\n"
    let @h = @h . "\" " . g:NERDTreeMapOpenVSplit . ": open vsplit\n"
    let @h = @h . "\" " . g:NERDTreeMapPreviewVSplit . ": preview vsplit\n"
    let @h = @h . "\"\n\" ----------------------------\n"
    let @h = @h . "\" Directory node mappings~\n"
    let @h = @h . "\" " . (g:NERDTreeMouseMode ==# 1 ? "double" : "single") . "-click,\n"
    let @h = @h . "\" " . g:NERDTreeMapActivateNode . ": open & close node\n"
    let @h = @h . "\" " . g:NERDTreeMapOpenRecursively . ": recursively open node\n"
    let @h = @h . "\" " . g:NERDTreeMapCloseDir . ": close parent of node\n"
    let @h = @h . "\" " . g:NERDTreeMapCloseChildren . ": close all child nodes of\n"
    let @h = @h . "\"    current node recursively\n"
    let @h = @h . "\" middle-click,\n"
    let @h = @h . "\" " . g:NERDTreeMapOpenExpl . ": explore selected dir\n"
    let @h = @h . "\"\n\" ----------------------------\n"
    let @h = @h . "\" Bookmark table mappings~\n"
    let @h = @h . "\" double-click,\n"
    let @h = @h . "\" " . g:NERDTreeMapActivateNode . ": open bookmark\n"
    let @h = @h . "\" " . g:NERDTreeMapOpenInTab . ": open in new tab\n"
    let @h = @h . "\" " . g:NERDTreeMapOpenInTabSilent . ": open in new tab silently\n"
    let @h = @h . "\" " . g:NERDTreeMapDeleteBookmark . ": delete bookmark\n"
    let @h = @h . "\"\n\" ----------------------------\n"
    let @h = @h . "\" Tree navigation mappings~\n"
    let @h = @h . "\" " . g:NERDTreeMapJumpRoot . ": go to root\n"
    let @h = @h . "\" " . g:NERDTreeMapJumpParent . ": go to parent\n"
    let @h = @h . "\" " . g:NERDTreeMapJumpFirstChild . ": go to first child\n"
    let @h = @h . "\" " . g:NERDTreeMapJumpLastChild . ": go to last child\n"
    let @h = @h . "\" " . g:NERDTreeMapJumpNextSibling . ": go to next sibling\n"
    let @h = @h . "\" " . g:NERDTreeMapJumpPrevSibling . ": go to prev sibling\n"
    let @h = @h . "\"\n\" ----------------------------\n"
    let @h = @h . "\" Filesystem mappings~\n"
    let @h = @h . "\" " . g:NERDTreeMapChangeRoot . ": change tree root to the\n"
    let @h = @h . "\"    selected dir\n"
    let @h = @h . "\" " . g:NERDTreeMapUpdir . ": move tree root up a dir\n"
    let @h = @h . "\" " . g:NERDTreeMapUpdirKeepOpen . ": move tree root up a dir\n"
    let @h = @h . "\"    but leave old root open\n"
    let @h = @h . "\" " . g:NERDTreeMapRefresh . ": refresh cursor dir\n"
    let @h = @h . "\" " . g:NERDTreeMapRefreshRoot . ": refresh current root\n"
    let @h = @h . "\" " . g:NERDTreeMapMenu . ": Show menu\n"
    let @h = @h . "\" " . g:NERDTreeMapChdir . ":change the CWD to the\n"
    let @h = @h . "\"    selected dir\n"
    let @h = @h . "\" " . g:NERDTreeMapCWD . ":change tree root to CWD\n"
    let @h = @h . "\"\n\" ----------------------------\n"
    let @h = @h . "\" Tree filtering mappings~\n"
    let @h = @h . "\" " . g:NERDTreeMapToggleHidden . ": hidden files (" . (b:NERDTreeShowHidden ? "on" : "off") . ")\n"
    let @h = @h . "\" " . g:NERDTreeMapToggleFilters . ": file filters (" . (b:NERDTreeIgnoreEnabled ? "on" : "off") . ")\n"
    let @h = @h . "\" " . g:NERDTreeMapToggleFiles . ": files (" . (b:NERDTreeShowFiles ? "on" : "off") . ")\n"
    let @h = @h . "\" " . g:NERDTreeMapToggleBookmarks . ": bookmarks (" . (b:NERDTreeShowBookmarks ? "on" : "off") . ")\n"
    let @h = @h . "\"\n\" ----------------------------\n"
    let @h = @h . "\" Custom mappings~\n"
    for i in g:NERDTreeKeyMap.All()
      if !empty(i.quickhelpText)
        let @h = @h . "\" " . i.key . ": " . i.quickhelpText . "\n"
      endif
    endfor
    let @h = @h . "\"\n\" ----------------------------\n"
    let @h = @h . "\" Other mappings~\n"
    let @h = @h . "\" " . g:NERDTreeMapQuit . ": Close the NERDTree window\n"
    let @h = @h . "\" " . g:NERDTreeMapToggleZoom . ": Zoom (maximize-minimize)\n"
    let @h = @h . "\"    the NERDTree window\n"
    let @h = @h . "\" " . g:NERDTreeMapHelp . ": toggle help\n"
    let @h = @h . "\"\n\" ----------------------------\n"
    let @h = @h . "\" Bookmark commands~\n"
    let @h = @h . "\" :Bookmark <name>\n"
    let @h = @h . "\" :BookmarkToRoot <name>\n"
    let @h = @h . "\" :RevealBookmark <name>\n"
    let @h = @h . "\" :OpenBookmark <name>\n"
    let @h = @h . "\" :ClearBookmarks [<names>]\n"
    let @h = @h . "\" :ClearAllBookmarks\n"
    silent! put h
  elseif g:NERDTreeMinimalUI ==# 0
    let @h = "\" Press " . g:NERDTreeMapHelp . " for help\n"
    silent! put h
  endif
  let @h = old_h
endfunction
function! nerdtree#echo(msg)
  redraw
  echomsg "NERDTree: " . a:msg
endfunction
function! nerdtree#echoError(msg)
  echohl errormsg
  call nerdtree#echo(a:msg)
  echohl normal
endfunction
function! nerdtree#echoWarning(msg)
  echohl warningmsg
  call nerdtree#echo(a:msg)
  echohl normal
endfunction
function! nerdtree#firstUsableWindow()
  let i = 1
  while i <=# winnr("$")
    let bnum = winbufnr(i)
    if bnum !=# -1 && getbufvar(bnum, '&buftype') ==# '' && !getwinvar(i, '&previewwindow') && (!getbufvar(bnum, '&modified') || &hidden)
      return i
    endif
    let i += 1
  endwhile
  return -1
endfunction
function! nerdtree#getPath(ln)
  let line = getline(a:ln)
  let rootLine = g:NERDTreeFileNode.GetRootLineNum()
  if a:ln ==# rootLine
    return b:NERDTreeRoot.path
  endif
  if !g:NERDTreeDirArrows
    if line !~# '^ *[|`▸▾ ]' || line =~# '^$'
      return {}
    endif
  endif
  if line ==# nerdtree#treeUpDirLine()
    return b:NERDTreeRoot.path.getParent()
  endif
  let indent = nerdtree#indentLevelFor(line)
  let curFile = nerdtree#stripMarkupFromLine(line, 0)
  let wasdir = 0
  if curFile =~# '/$'
    let wasdir = 1
    let curFile = substitute(curFile, '/\?$', '/', "")
  endif
  let dir = ""
  let lnum = a:ln
  while lnum ># 0
    let lnum = lnum - 1
    let curLine = getline(lnum)
    let curLineStripped = nerdtree#stripMarkupFromLine(curLine, 1)
    if lnum ==# rootLine
      let dir = b:NERDTreeRoot.path.str({'format': 'UI'}) . dir
      break
    endif
    if curLineStripped =~# '/$'
      let lpindent = nerdtree#indentLevelFor(curLine)
      if lpindent <# indent
        let indent = indent - 1
        let dir = substitute(curLineStripped, '^\\', "", "") . dir
        continue
      endif
    endif
  endwhile
  let curFile = b:NERDTreeRoot.path.drive . dir . curFile
  let toReturn = g:NERDTreePath.New(curFile)
  return toReturn
endfunction
function! nerdtree#getTreeWinNum()
  if exists("t:NERDTreeBufName")
    return bufwinnr(t:NERDTreeBufName)
  else
    return -1
  endif
endfunction
function! nerdtree#indentLevelFor(line)
  let level = match(a:line, '[^ \-+~▸▾`|]') / nerdtree#treeWid()
  if match(a:line, '[▸▾]') ># -1
    let level = level - 1
  endif
  return level
endfunction
function! nerdtree#isTreeOpen()
  return nerdtree#getTreeWinNum() !=# -1
endfunction
function! nerdtree#isWindowUsable(winnumber)
  if winnr("$") ==# 1
    return 0
  endif
  let oldwinnr = winnr()
  call nerdtree#exec(a:winnumber . "wincmd p")
  let specialWindow = getbufvar("%", '&buftype') !=# '' || getwinvar('%', '&previewwindow')
  let modified = &modified
  call nerdtree#exec(oldwinnr . "wincmd p")
  if specialWindow
    return 0
  endif
  if &hidden
    return 1
  endif
  return !modified || nerdtree#bufInWindows(winbufnr(a:winnumber)) >=# 2
endfunction
function! nerdtree#jumpToChild(currentNode, direction)
  if a:currentNode.isRoot()
    return nerdtree#echo("cannot jump to " . (a:direction ? "last" : "first") . " child")
  endif
  let dirNode = a:currentNode.parent
  let childNodes = dirNode.getVisibleChildren()
  let targetNode = childNodes[0]
  if a:direction
    let targetNode = childNodes[len(childNodes) - 1]
  endif
  if targetNode.equals(a:currentNode)
    let siblingDir = a:currentNode.parent.findOpenDirSiblingWithVisibleChildren(a:direction)
    if siblingDir !=# {}
      let indx = a:direction ? siblingDir.getVisibleChildCount() - 1 : 0
      let targetNode = siblingDir.getChildByIndex(indx, 1)
    endif
  endif
  call targetNode.putCursorHere(1, 0)
  call nerdtree#centerView()
endfunction
function! nerdtree#jumpToSibling(currentNode, forward)
  let sibling = a:currentNode.findSibling(a:forward)
  if !empty(sibling)
    call sibling.putCursorHere(1, 0)
    call nerdtree#centerView()
  endif
endfunction
function! nerdtree#promptToDelBuffer(bufnum, msg)
  echo a:msg
  if nr2char(getchar()) ==# 'y'
    exec "silent bdelete! " . a:bufnum
  endif
endfunction
function! nerdtree#putCursorOnBookmarkTable()
  if !b:NERDTreeShowBookmarks
    throw "NERDTree.IllegalOperationError: cant find bookmark table, bookmarks arent active"
  endif
  if g:NERDTreeMinimalUI
    return cursor(1, 2)
  endif
  let rootNodeLine = g:NERDTreeFileNode.GetRootLineNum()
  let line = 1
  while getline(line) !~# '^>-\+Bookmarks-\+$'
    let line = line + 1
    if line >=# rootNodeLine
      throw "NERDTree.BookmarkTableNotFoundError: didnt find the bookmarks table"
    endif
  endwhile
  call cursor(line, 2)
endfunction
function! nerdtree#putCursorInTreeWin()
  if !nerdtree#isTreeOpen()
    throw "NERDTree.InvalidOperationError: cant put cursor in NERD tree window, no window exists"
  endif
  call nerdtree#exec(nerdtree#getTreeWinNum() . "wincmd w")
endfunction
function! nerdtree#renderBookmarks()
  if g:NERDTreeMinimalUI ==# 0
    call setline(line(".") + 1, ">----------Bookmarks----------")
    call cursor(line(".") + 1, col("."))
  endif
  for i in g:NERDTreeBookmark.Bookmarks()
    call setline(line(".") + 1, i.str())
    call cursor(line(".") + 1, col("."))
  endfor
  call setline(line(".") + 1, '')
  call cursor(line(".") + 1, col("."))
endfunction
function! nerdtree#renderView()
  setlocal modifiable
  let curLine = line(".")
  let curCol = col(".")
  let topLine = line("w0")
  silent 1,$delete _
  call nerdtree#dumpHelp()
  if g:NERDTreeMinimalUI ==# 0
    call setline(line(".") + 1, "")
    call cursor(line(".") + 1, col("."))
  endif
  if b:NERDTreeShowBookmarks
    call nerdtree#renderBookmarks()
  endif
  if !g:NERDTreeMinimalUI
    call setline(line(".") + 1, nerdtree#treeUpDirLine())
    call cursor(line(".") + 1, col("."))
  endif
  let header = b:NERDTreeRoot.path.str({'format': 'UI', 'truncateTo': winwidth(0)})
  call setline(line(".") + 1, header)
  call cursor(line(".") + 1, col("."))
  let old_o = @o
  let @o = b:NERDTreeRoot.renderToString()
  silent put o
  let @o = old_o
  silent 1,1delete _
  let old_scrolloff = &scrolloff
  let &scrolloff = 0
  call cursor(topLine, 1)
  normal! zt
  call cursor(curLine, curCol)
  let &scrolloff = old_scrolloff
  setlocal nomodifiable
endfunction
function! nerdtree#renderViewSavingPosition()
  let currentNode = g:NERDTreeFileNode.GetSelected()
  while currentNode !=# {} && !currentNode.isVisible() && !currentNode.isRoot()
    let currentNode = currentNode.parent
  endwhile
  call nerdtree#renderView()
  if currentNode !=# {}
    call currentNode.putCursorHere(0, 0)
  endif
endfunction
function! nerdtree#restoreScreenState()
  if !exists("b:NERDTreeOldTopLine") || !exists("b:NERDTreeOldPos") || !exists("b:NERDTreeOldWindowSize")
    return
  endif
  exec("silent vertical resize ".b:NERDTreeOldWindowSize)
  let old_scrolloff = &scrolloff
  let &scrolloff = 0
  call cursor(b:NERDTreeOldTopLine, 0)
  normal! zt
  call setpos(".", b:NERDTreeOldPos)
  let &scrolloff = old_scrolloff
endfunction
function! nerdtree#saveScreenState()
  let win = winnr()
  try
    call nerdtree#putCursorInTreeWin()
    let b:NERDTreeOldPos = getpos(".")
    let b:NERDTreeOldTopLine = line("w0")
    let b:NERDTreeOldWindowSize = winwidth("")
    call nerdtree#exec(win . "wincmd w")
  catch /^NERDTree.InvalidOperationError/
  endtry
endfunction
function! nerdtree#stripMarkupFromLine(line, removeLeadingSpaces)
  let line = a:line
  let line = substitute(line, nerdtree#treeMarkupReg(), "", "")
  let line = substitute(line, ' \[RO\]', "", "")
  let line = substitute(line, ' {[^}]*}', "", "")
  let line = substitute(line, '*\ze\($\| \)', "", "")
  let wasdir = 0
  if line =~# '/$'
    let wasdir = 1
  endif
  let line = substitute(line, ' -> .*', "", "")
  if wasdir ==# 1
    let line = substitute(line, '/\?$', '/', "")
  endif
  if a:removeLeadingSpaces
    let line = substitute(line, '^ *', '', '')
  endif
  return line
endfunction
function! s:activateAll()
  if getline(".") ==# nerdtree#treeUpDirLine()
    return nerdtree#upDir(0)
  endif
endfunction
function! s:activateDirNode(node)
  call a:node.activate({'reuse': 1})
endfunction
function! s:activateFileNode(node)
  call a:node.activate({'reuse': 1, 'where': 'p'})
endfunction
function! s:activateBookmark(bm)
  call a:bm.activate(!a:bm.path.isDirectory ? {'where': 'p'} : {})
endfunction
function! nerdtree#bookmarkNode(...)
  let currentNode = g:NERDTreeFileNode.GetSelected()
  if currentNode !=# {}
    let name = a:1
    if empty(name)
      let name = currentNode.path.getLastPathComponent(0)
    endif
    try
      call currentNode.bookmark(name)
      call nerdtree#renderView()
    catch /^NERDTree.IllegalBookmarkNameError/
      call nerdtree#echo("bookmark names must not contain spaces")
    endtry
  else
    call nerdtree#echo("select a node first")
  endif
endfunction
function! s:chCwd(node)
  try
    call a:node.path.changeToDir()
  catch /^NERDTree.PathChangeError/
    call nerdtree#echoWarning("could not change cwd")
  endtry
endfunction
function! s:chRoot(node)
  call a:node.makeRoot()
  call nerdtree#renderView()
  call b:NERDTreeRoot.putCursorHere(0, 0)
endfunction
function! nerdtree#chRootCwd()
  try
    let cwd = g:NERDTreePath.New(getcwd())
  catch /^NERDTree.InvalidArgumentsError/
    call nerdtree#echo("current directory does not exist.")
    return
  endtry
  if cwd.str() ==# g:NERDTreeFileNode.GetRootForTab().path.str()
    return
  endif
  call nerdtree#chRoot(g:NERDTreeDirNode.New(cwd))
endfunction
function! nerdtree#clearBookmarks(bookmarks)
  if a:bookmarks ==# ''
    let currentNode = g:NERDTreeFileNode.GetSelected()
    if currentNode !=# {}
      call currentNode.clearBookmarks()
    endif
  else
    for name in split(a:bookmarks, ' ')
      let bookmark = g:NERDTreeBookmark.BookmarkFor(name)
      call bookmark.delete()
    endfor
  endif
  call nerdtree#renderView()
endfunction
function! s:closeChildren(node)
  call a:node.closeChildren()
  call nerdtree#renderView()
  call a:node.putCursorHere(0, 0)
endfunction
function! s:closeCurrentDir(node)
  let parent = a:node.parent
  if parent ==# {} || parent.isRoot()
    call nerdtree#echo("cannot close tree root")
  else
    call a:node.parent.close()
    call nerdtree#renderView()
    call a:node.parent.putCursorHere(0, 0)
  endif
endfunction
function! s:closeTreeWindow()
  if b:NERDTreeType ==# "secondary" && b:NERDTreePreviousBuf !=# -1
    exec "buffer " . b:NERDTreePreviousBuf
  else
    if winnr("$") ># 1
      call nerdtree#closeTree()
    else
      call nerdtree#echo("Cannot close last window")
    endif
  endif
endfunction
function! s:deleteBookmark(bm)
  echo "Are you sure you wish to delete the bookmark:\n\"" . a:bm.name . "\" (yN):"
  if nr2char(getchar()) ==# 'y'
    try
      call a:bm.delete()
      call nerdtree#renderView()
      redraw
    catch /^NERDTree/
      call nerdtree#echoWarning("Could not remove bookmark")
    endtry
  else
    call nerdtree#echo("delete aborted")
  endif
endfunction
function! s:displayHelp()
  let b:treeShowHelp = b:treeShowHelp ? 0 : 1
  call nerdtree#renderView()
  call nerdtree#centerView()
endfunction
function! s:handleLeftClick()
  let currentNode = g:NERDTreeFileNode.GetSelected()
  if currentNode !=# {}
    let line = split(getline(line(".")), '\zs')
    let startToCur = ""
    for i in range(0, len(line) - 1)
      let startToCur .= line[i]
    endfor
    if currentNode.path.isDirectory
      if startToCur =~# nerdtree#treeMarkupReg() && startToCur =~# '[+~▾▸] \?$'
        call currentNode.activate()
        return
      endif
    endif
    if (g:NERDTreeMouseMode ==# 2 && currentNode.path.isDirectory) || g:NERDTreeMouseMode ==# 3
      let char = strpart(startToCur, strlen(startToCur) - 1, 1)
      if char !~# nerdtree#treeMarkupReg()
        if currentNode.path.isDirectory
          call currentNode.activate()
        else
          call currentNode.activate({'reuse': 1, 'where': 'p'})
        endif
        return
      endif
    endif
  endif
endfunction
function! s:handleMiddleMouse()
  let curNode = g:NERDTreeFileNode.GetSelected()
  if curNode ==# {}
    call nerdtree#echo("Put the cursor on a node first")
    return
  endif
  if curNode.path.isDirectory
    call nerdtree#openExplorer(curNode)
  else
    call curNode.open({'where': 'h'})
  endif
endfunction
function! s:jumpToFirstChild(node)
  call nerdtree#jumpToChild(a:node, 0)
endfunction
function! s:jumpToLastChild(node)
  call nerdtree#jumpToChild(a:node, 1)
endfunction
function! s:jumpToParent(node)
  if !empty(a:node.parent)
    call a:node.parent.putCursorHere(1, 0)
    call nerdtree#centerView()
  else
    call nerdtree#echo("cannot jump to parent")
  endif
endfunction
function! s:jumpToRoot()
  call b:NERDTreeRoot.putCursorHere(1, 0)
  call nerdtree#centerView()
endfunction
function! s:jumpToNextSibling(node)
  call nerdtree#jumpToSibling(a:node, 1)
endfunction
function! s:jumpToPrevSibling(node)
  call nerdtree#jumpToSibling(a:node, 0)
endfunction
function! nerdtree#openBookmark(name)
  try
    let targetNode = g:NERDTreeBookmark.GetNodeForName(a:name, 0)
    call targetNode.putCursorHere(0, 1)
    redraw!
  catch /^NERDTree.BookmarkedNodeNotFoundError/
    call nerdtree#echo("note - target node is not cached")
    let bookmark = g:NERDTreeBookmark.BookmarkFor(a:name)
    let targetNode = g:NERDTreeFileNode.New(bookmark.path)
  endtry
  if targetNode.path.isDirectory
    call targetNode.openExplorer()
  else
    call targetNode.open({'where': 'p'})
  endif
endfunction
function! s:openHSplit(target)
  call a:target.activate({'where': 'h'})
endfunction
function! s:openVSplit(target)
  call a:target.activate({'where': 'v'})
endfunction
function! s:openExplorer(node)
  call a:node.openExplorer()
endfunction
function! s:openInNewTab(target)
  call a:target.activate({'where': 't'})
endfunction
function! s:openInNewTabSilent(target)
  call a:target.activate({'where': 't', 'stay': 1})
endfunction
function! s:openNodeRecursively(node)
  call nerdtree#echo("Recursively opening node. Please wait...")
  call a:node.openRecursively()
  call nerdtree#renderView()
  redraw
  call nerdtree#echo("Recursively opening node. Please wait... DONE")
endfunction
function! s:previewNodeCurrent(node)
  call a:node.open({'stay': 1, 'where': 'p', 'keepopen': 1})
endfunction
function! s:previewNodeHSplit(node)
  call a:node.open({'stay': 1, 'where': 'h', 'keepopen': 1})
endfunction
function! s:previewNodeVSplit(node)
  call a:node.open({'stay': 1, 'where': 'v', 'keepopen': 1})
endfunction
function! nerdtree#revealBookmark(name)
  try
    let targetNode = g:NERDTreeBookmark.GetNodeForName(a:name, 0)
    call targetNode.putCursorHere(0, 1)
  catch /^NERDTree.BookmarkNotFoundError/
    call nerdtree#echo("Bookmark isnt cached under the current root")
  endtry
endfunction
function! s:refreshRoot()
  call nerdtree#echo("Refreshing the root node. This could take a while...")
  call b:NERDTreeRoot.refresh()
  call nerdtree#renderView()
  redraw
  call nerdtree#echo("Refreshing the root node. This could take a while... DONE")
endfunction
function! s:refreshCurrent(node)
  let node = a:node
  if !node.path.isDirectory
    let node = node.parent
  endif
  call nerdtree#echo("Refreshing node. This could take a while...")
  call node.refresh()
  call nerdtree#renderView()
  redraw
  call nerdtree#echo("Refreshing node. This could take a while... DONE")
endfunction
function! s:showMenu(node)
  let mc = g:NERDTreeMenuController.New(g:NERDTreeMenuItem.AllEnabled())
  call mc.showMenu()
endfunction
function! s:toggleIgnoreFilter()
  let b:NERDTreeIgnoreEnabled = !b:NERDTreeIgnoreEnabled
  call nerdtree#renderViewSavingPosition()
  call nerdtree#centerView()
endfunction
function! s:toggleShowBookmarks()
  let b:NERDTreeShowBookmarks = !b:NERDTreeShowBookmarks
  if b:NERDTreeShowBookmarks
    call nerdtree#renderView()
    call nerdtree#putCursorOnBookmarkTable()
  else
    call nerdtree#renderViewSavingPosition()
  endif
  call nerdtree#centerView()
endfunction
function! s:toggleShowFiles()
  let b:NERDTreeShowFiles = !b:NERDTreeShowFiles
  call nerdtree#renderViewSavingPosition()
  call nerdtree#centerView()
endfunction
function! s:toggleShowHidden()
  let b:NERDTreeShowHidden = !b:NERDTreeShowHidden
  call nerdtree#renderViewSavingPosition()
  call nerdtree#centerView()
endfunction
function! s:toggleZoom()
  if exists("b:NERDTreeZoomed") && b:NERDTreeZoomed
    let size = exists("b:NERDTreeOldWindowSize") ? b:NERDTreeOldWindowSize : g:NERDTreeWinSize
    exec "silent vertical resize " . size
    let b:NERDTreeZoomed = 0
  else
    exec "vertical resize"
    let b:NERDTreeZoomed = 1
  endif
endfunction
function! s:upDirCurrentRootOpen()
  call nerdtree#upDir(1)
endfunction
function! s:upDirCurrentRootClosed()
  call nerdtree#upDir(0)
endfunction
