#!/usr/bin/env python
__version__ = '0.0.4-dev' # script-mpe
__db__ = 'postgresql+psycopg2://redmine:password@localhost:15432/redmine_production'
__usage__ = """
redmine-meta - Read data from Redmine database.

Usage:
    rdm [options] issues
    rdm [options] projects
    rdm [options] custom-fields
    rdm [options] print-db-ref
    rdm [options] run-indexer
    rdm [options] home-doc [ISSUE]

Options:
    -v            Increase verbosity.
    -d REF --dbref=REF
                  SQLAlchemy DB URL [default: %s].
    -y --yes
    -V, --version  Show version (%s).

Dependencies:
  psycopg2
    postgresql-devel (Debian: libpq-dev)
      ..

""" % ( __db__, __version__ )
from __future__ import print_function
from script_mpe import libcmd_docopt, log
from script_mpe import redmine_schema as rdm
from script_mpe.redmine_schema import get_session



def get_custom_field(name, sa=None):
    return sa.query(rdm.CustomField).filter(
            rdm.CustomField.name == name ).one()



### Program sub-commands


def cmd_projects(settings):

    """
        List projects, with id and parent id.
    """

    sa = get_session(settings.dbref)
    l = 'Projects'
    v = sa.query(rdm.Project).count()
    # TODO: filter project; age, public
    log.info('{green}%s{default}: {bwhite}%s{default}', l, v)
    print('# ID PARENT NAME')
    for p in sa.query(rdm.Project).all():
        print(p.id, p.parent_id or '-', p.name)


def cmd_issues(settings):

    """
        List issues
    """

    sa = get_session(settings.dbref)
    l = 'Issues'
    # TODO: filter issues; where not closed, where due, started, etc.
    v = sa.query(rdm.Issue).count()
    log.info('{green}%s{default}: {bwhite}%s{default}', l, v)
    print('# ID PARENT_ID ROOT_ID SUBJECT ')
    #print('# ID PARENT_ID ROOT_ID PRIO SUBJECT ')
    for i in sa.query(rdm.Issue).all():
        print(i.id,)
        for k in i.parent_id, i.root_id:
            print(k or '-',)
        #print i.priority_id or '-', i.subject
        print(i.subject)


def cmd_custom_fields(settings):

    """
        List custom-fields
    """

    sa = get_session(settings.dbref)
    l = 'Custom Fields'
    # TODO: filter custom_fields;
    v = sa.query(rdm.CustomField).count()
    log.info('{green}%s{default}: {bwhite}%s{default}', l, v)
    for rs in sa.query(rdm.CustomField).all():
        print(rs.id, rs.type)
        print("  Name:", rs.name)
        if rs.possible_values: # yaml value
            print("  Possible values: ")
            for x in rs.possible_values.split('\n'):
                if x == '---': continue
                print("  ",x)
        if rs.description:
            print("  Description:")
            print("   ", rs.description.replace('\n', '\n    '))


def cmd_print_db_ref(settings):
    "Print DB after parsing settings. "
    print(settings.dbref)


def cmd_run_indexer(settings):
    "TODO: Update subjects for projects with index mode set"
    sa = get_session(settings.dbref)
    index_cf = get_custom_field('Index Method', sa)
    index_offset_cf = get_custom_field('Index Offset', sa)
    for project, idx_cf_v in sa.query(rdm.Project, rdm.CustomValue).join(
                rdm.CustomValue,
                rdm.CustomValue.customized_id == rdm.Project.id
            ).filter(
                rdm.CustomValue.custom_field_id == index_cf.id
            ).all():

        index_mode = idx_cf_v.value
        if index_mode:
            print('# TODO index project, index_mode')

    #index_current_cf = get_custom_field('Index Method', sa)


def cmd_home_doc(settings, opts):
    sa = get_session(settings.dbref)
    home_doc_cf = get_custom_field('Home Doc', sa)
    proj_id_cf = get_custom_field('ID Slug', sa)
    assert home_doc_cf.field_format == 'link', home_doc_cf.field_format
    # yaml
    assert home_doc_cf.format_store.startswith('---')
    format = home_doc_cf.format_store.split('\n')[1:]
    assert format[0].startswith('url_pattern: '),\
            format
    url_pattern = format[0][len('url_pattern: '):]

    if opts.args.ISSUE:
        iid = int(opts.args.ISSUE)
        issue, home_doc_cf_v = sa.query(rdm.Issue, rdm.CustomValue).join(
                rdm.CustomValue,
                rdm.CustomValue.customized_id == rdm.Issue.id
            ).filter(
                rdm.CustomValue.custom_field_id == home_doc_cf.id,
                rdm.Issue.id == iid
            ).one()

        project, proj_id_cf_v = sa.query(rdm.Project, rdm.CustomValue).join(
                rdm.CustomValue,
                rdm.CustomValue.customized_id == rdm.Project.id
            ).filter(
                rdm.CustomValue.custom_field_id == proj_id_cf.id,
                rdm.Project.id == issue.project_id
            ).one()

        if not home_doc_cf_v.value:
            log.warn("No Home Doc")
            return 1

        if proj_id_cf_v.value:
            id_slug = proj_id_cf_v.value
        else:
            id_slug = ''

        url = url_pattern.replace('%project_identifier%', id_slug)
        url = url.replace('%project_id%', str(issue.project_id))
        url = url.replace('%value%', home_doc_cf_v.value)
        url = url.replace('%id%', str(issue.id))

        print(url, issue.subject)
    else:
        print(url_pattern)




### Transform cmd_ function names to nested dict

commands = libcmd_docopt.get_cmd_handlers_2(globals(), 'cmd_')



### Util functions to run above functions from cmdline

def main(opts):

    """
    Execute command.
    """

    settings = opts.flags
    opts.default = ['info']
    return libcmd_docopt.run_commands(commands, settings, opts)

def get_version():
    return 'redmine-meta.mpe/%s' % __version__

argument_handlers = {
}

if __name__ == '__main__':

    import sys
    opts = libcmd_docopt.get_opts(__usage__, meta=argument_handlers, version=get_version())
    opts.flags.dbref = opts.flags.dbref
    sys.exit(main(opts))
