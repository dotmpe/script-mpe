def load_module(p):
    names, path, c, name = p.split('.'), [], {}, None
    while names:
        fromlist = []
        if name and name in c:
            fromlist = [c[name]]
        name = names.pop(0)
        path.append(name)
        c[name] = __import__(".".join(path), fromlist=fromlist)
    return c[name]
