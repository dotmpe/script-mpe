import re

from script_mpe import lib



def detect_remote_urls(repo, g):
    for r in repo['remotes']:
        url = repo['remotes'][r]['url']
        if not url: continue
        yield url


vendor_path = re.compile(
r'^.*\b([A-Za-z0-9_-]+\.[a-z]+)(:|\/)([A-Za-z0-9_-]+)\/([A-Za-z0-9_-]+)(?:\.[a-z]+)?$')

def detect_project(repo, g):
    if 'remotes' not in repo or not repo['remotes']:
        return
    choices = []
    for url in detect_remote_urls(repo, g):
        m = vendor_path.match( url )
        if m:
            m = m.groups()
            choices.append(m[3])
    return choices

def detect_vendor(repo, g):
    if 'remotes' not in repo or not repo['remotes']:
        return
    choices = []
    for url in detect_remote_urls(repo, g):
        m = vendor_path.match( url )
        if m:
            m = m.groups()
            choices.append(m[0]+'/'+m[2])
    return choices


def select(prop, repo, choices, g):
    if not choices:
        raise ValueError("Expected at least one value for %s in %s" % (prop, repo))
    if len(choices) == 1:
        return choices[0]
    elif not g.interactive:
        raise ValueError("Multiple values for %s: %r" %( prop, choices ))
    else:
        return lib.Prompt.pick("Select item to use as %s" % prop, choices)

def catalog(prefix, repo, g):
    updated = False

    if 'vendor' in repo and not repo['vendor']:
        del repo['vendor']
    if 'vendor' not in repo:
        choices = detect_vendor(repo, g)
        if choices:
            repo['vendor'] = select('vendor', repo, choices, g)
            updated = True

    #if 'type' not in repo or not repo['type']:
    #    repo['type'] = lib.cmd(['vc', 'type', p])

    if 'id' in repo and not repo['id']:
        del repo['id']
    if 'id' not in repo:
        choices = detect_project(repo, g)
        if choices:
            repo['id'] = select('id', repo, choices, g)
            updated = True

    return updated
