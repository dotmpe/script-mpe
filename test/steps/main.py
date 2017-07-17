import re
from subprocess import Popen, PIPE

from behave import use_step_matcher
use_step_matcher("re")





def theUserRuns(ctx, sh, err):
    p = Popen(sh, shell=True, stdin=PIPE, stdout=PIPE, stderr=PIPE, close_fds=True)
    p.wait()
    ctx.status = p.returncode
    if ctx.status is None: ctx.status = 0
    ctx.output = ctx.stdout = p.stdout.read()
    ctx.stderr = p.stderr.read()
    if not err and p.returncode:
        raise Exception("User run returned %i" % p.returncode)

@when( u'the user runs "(?P<sh>.*)"(?P<err>\?|\.*)?' )
def when_theUserRuns(ctx, sh, err):
    """Given shell command `sh`. Use '...' or '?' to allow non-zero exit. """
    theUserRuns(ctx, sh, err)

@when( u'the user runs(?P<err>\?|\.*)?' )
def when_theUserRunsMultiline(ctx, err):
    """Read shell command from subsequent multiline. See the-user-runs. """
    theUserRuns(ctx, ctx.text, err)



@then( u'`(?P<attr>.*)` (?P<mode>contains|matches) the pattern "(?P<rx>.*)"' )
def ctxStringAttrRegex(ctx, attr, mode, rx):
    v = getattr( ctx, attr )
    if mode == 'contains':
        if not re.search( rx, v ):
            raise Exception("Missing pattern %r: %s" % ( rx, v ))
    elif mode == 'matches':
        if not re.match( rx, v ):
            raise Exception("Missing pattern %r: %s" % ( rx, v ))
    else:
        raise Exception("Unknown mode %s" % mode)



@then( u'`(?P<a>.*)` (?P<m>contains|matches) the patterns' )
def ctxStringAttrEveryRegex(ctx, a, m):
    v = getattr( ctx, a )
    lines = [ l.strip() for l in ctx.text.split('\n') ]
    for l in lines:
        ctxStringAttrRegex(ctx, a, m, l)



@then( u'`(?P<attr>.*)` should be \'(?P<s>.*)\'' )
def ctxStringAttrShouldBe(ctx, attr, s, inverse=False):
    s = s.encode('utf-8')
    v = str(getattr( ctx, attr ))
    if not inverse:
        if not ( v is s ):
            raise Exception("Unexpected %r != %r" % ( v, s ))
    else:
        if v is s:
            raise Exception("Unexpected %r == %r" % ( v, s ))



@then( u'`(?P<attr>.*)` should not be \'(?P<s>.*)\'' )
def then_ctxStringAttrShouldNotBe(ctx, attr, s):
    ctxStringAttrShouldBe(ctx, attr, s, inverse=True)



@given( "the current (?P<name>.*)," )
def theCurrent(ctx, name):
    pass



@then( "file '(?P<fn>.*)' should have" )
def fileShouldHaveMultiline(ctx, fn):
    if open(fn).read().strip() != ctx.text.strip():
        raise Exception("Mismatch")



# Catch numbered steps; possibly do lookup

@given( r'(?P<Id>[0-9\.]+)\s(?P<step>.*)(?P<Refs>\[[0-9\.\ -]+\])?')
@when(  r'(?P<Id>[0-9\.]+)\s(?P<step>.*)(?P<Refs>\[[0-9\.\ -]+\])?')
@then(  r'(?P<Id>[0-9\.]+)\s(?P<step>.*)(?P<Refs>\[[0-9\.\ -]+\])?')
def step_impl(ctx, Id, step, Refs):
    print( ctx.returncode, ctx.output, ctx.stderr )
    raise NotImplementedError(u'TODO: DEF: %s"' % step)


# Catch all other steps
@given( r'(?P<step>.*)' )
@when(  r'(?P<step>.*)' )
@then(  r'(?P<step>.*)' )
def step_impl(ctx, step):
    raise NotImplementedError(u'TODO: STEP: %s"' % step)



