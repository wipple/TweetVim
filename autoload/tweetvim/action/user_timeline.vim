"
"
"
function! tweetvim#action#user_timeline#define()
  return {
        \ 'description' : 'show user timeline',
        \ }
endfunction
"
"
"
function! tweetvim#action#user_timeline#execute(tweet)
  call tweetvim#timeline('user_timeline', a:tweet.user.screen_name)
endfunction