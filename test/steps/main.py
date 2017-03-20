
from behave import use_step_matcher
use_step_matcher("re")



@when( u'the user runs "(?P<sh>.*)(?P<err>\?)?"' )
def theUserRuns(context, sh, err):
    pass




# Catch numbered steps; possibly do lookup

@given( r'(?P<Id>[0-9\.]+)\s(?P<step>.*)(?P<Refs>\[[0-9\.\ -]+\])?')
@when(  r'(?P<Id>[0-9\.]+)\s(?P<step>.*)(?P<Refs>\[[0-9\.\ -]+\])?')
@then(  r'(?P<Id>[0-9\.]+)\s(?P<step>.*)(?P<Refs>\[[0-9\.\ -]+\])?')
def step_impl(ctx, Id, step, Refs):
    raise NotImplementedError(u'TODO: DEF: %s"' % step)


# Catch all other steps
@given( r'(?P<step>.*)' )
@when(  r'(?P<step>.*)' )
@then(  r'(?P<step>.*)' )
def step_impl(ctx, step):
    raise NotImplementedError(u'TODO: STEP: %s"' % step)



