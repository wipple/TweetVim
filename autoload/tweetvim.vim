let s:consumer_key    = '8hht6fAi3wU47cwql0Cbkg'
let s:consumer_secret = 'sbmqcNqlfwpBPk8QYdjwlaj0PIZFlbEXvSxxNrJDcAU'
"
"
"
let s:cache = {}
"
"
"
"
function! tweetvim#timeline(method, ...)
  " TODO - for list_statuses at tweetvim/timeline action
  let args = (a:0 == 1 && type(a:1) == 3) ? a:1 : a:000

  let tweets = tweetvim#request(a:method, args)

  if type(tweets) == 4 && has_key(tweets, 'error')
    echohl Error | echo tweets.error | echohl None
    return
  endif
  " TODO:
  " delete cache for previous and next
  " buf no is -1 -2 -3 ... oldest
  let bufno = get(b:, 'tweetvim_bufno', 0)
  if bufno < -1
    call tweetvim#buffer#truncate_backup(bufno)
  endif

  call tweetvim#buffer#load(
        \ a:method,
        \ a:000,
        \ join(split(a:method, '_'), ' '), 
        \ tweets)

  call s:write_cache('screen_name', map(tweets, 'v:val.user.screen_name'))
endfunction
"
"
"
function! tweetvim#access_token()
  
  let token_path = g:tweetvim_config_dir . '/token'
  if filereadable(token_path)
    return readfile(token_path)
  endif

  let ctx = twibill#access_token({
              \ 'consumer_key'    : s:consumer_key,
              \ 'consumer_secret' : s:consumer_secret,
              \ })
  let tokens = [ctx.access_token, ctx.access_token_secret]

  call writefile(tokens , token_path)

  return tokens
endfunction
"
"
"
function! tweetvim#request(method, args)
  let args  = type(a:args) == 3 ? a:args : [a:args]
  let param = {'per_page' : 50, 'count' : 50}
  let args  = s:merge_params(args, param)

  let twibill = s:twibill()
  let Fn      = twibill[a:method]

  return call(Fn, args, twibill)
endfunction
"
"
"
function! tweetvim#update(text, param)
  return tweetvim#request('update', [a:text, a:param])
endfunction
"
"
"
function! tweetvim#action(name)
  let tweet = get(b:tweetvim_status_cache, line('.'), {})
  " TODO
  if a:name != 'reload' && a:name != 'page_next' && a:name != 'page_previous' && empty(tweet)
    echo 'no action'
    return
  endif
  let Fn = function('tweetvim#action#' . a:name . '#execute')
  call Fn(tweet)
endfunction
"
"
"
function! tweetvim#verify_credentials()
  if !exists('s:credencidals')
    let credencidals = tweetvim#request('verify_credentials', [])
    if has_key(credencidals, 'error')
      echohl Error | echo credencidals.error | echohl None
      return {}
    endif
    let s:credencidals = credencidals
  endif
  return copy(s:credencidals)
endfunction
"
"
"
function! tweetvim#lists()
  if !exists('s:cache_lists')
    let info = tweetvim#verify_credentials()
    if empty(info)
      return []
    endif
    let s:cache_lists = tweetvim#request('lists', [info.screen_name]).lists
  endif
  return copy(s:cache_lists)
endfunction
"
"
"
function! s:config()
  let tokens = tweetvim#access_token()
  return {
    \ 'consumer_key'        : s:consumer_key ,
    \ 'consumer_secret'     : s:consumer_secret ,
    \ 'access_token'        : tokens[0] ,
    \ 'access_token_secret' : tokens[1] ,
    \ 'cache'               : 1
    \ }
endfunction
"
"
"
function! s:twibill()
  if exists('s:twibill_cache')
    return s:twibill_cache
  endif
  let s:twibill_cache = tweetvim#twibill#new(s:config())
  return s:twibill_cache
endfunction
"
"
"
function! s:merge_params(list_param, hash_param)
  if empty(a:list_param)
    return [a:hash_param]
  endif

  let param = a:list_param

  if type(param[-1]) == 4
    call extend(a:hash_param, param[-1])
    return param
  endif

  return param + [a:hash_param]
endfunction
"
"
"
function! s:read_cache(fname)
  let path = g:tweetvim_config_dir . '/' . a:fname
  if !filereadable(path)
    return
  endif
  " cache
  let cache = {}
  for name in readfile(path)
    if name != ""
      let cache[name] = 1
    endif
  endfor

  let s:cache[a:fname] = cache
  let s:cache[a:fname . '_ftime'] = getftime(path)
endfunction
"
"
"
function! s:write_cache(fname, list)
  let path  = g:tweetvim_config_dir . '/' . a:fname
  let cache = s:cache[a:fname]
  let size  = len(cache)
  " check local change
  if getftime(path) != s:cache[a:fname . '_ftime']
      call s:read_cache(a:fname)
  endif
  " update buffer cache
  for name in a:list
    let s:cache[a:fname][name] = 1
  endfor
  " check updatable
  if size == len(s:cache[a:fname])
    return
  endif
  " TODO : merge if local file is updated
  call writefile(sort(keys(s:cache[a:fname])), path)
endfunction
"
call s:read_cache('screen_name')
