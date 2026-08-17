# code/

Full, runnable code for blog post experiments — kept outside `content/` so
Hugo never processes or publishes it, and separate from the trimmed
snippets shown inline in posts so the two don't silently drift apart.

One subfolder per post, named after the post's slug:

```
code/
  simulating-a-random-walk-in-python/
    walk.py
    walk_np.py
    walk.cpp
    requirements.txt   (if it has Python deps beyond the stdlib/NumPy)
```

A post links out to its folder (e.g.
`github.com/feribg/randomwalk.dev/tree/main/code/<slug>/`) for the full
version, while the post body keeps a shorter, curated excerpt for
readability.
