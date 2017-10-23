import os

from script_mpe.confparse import yaml_load, yaml_safe_dump


class Diskdoc(object):

    def __init__(self, data):
        self.data = data

    def __getitem__(self, key):
        return self.data[key]

    def __setitem__(self, key, v):
        self.data[key] = v

    @classmethod
    def from_user_path(Cls, fname):
        "Load and instantiate from YAML doc"
        diskdoc = os.path.expanduser(fname)
        diskdata = yaml_load(open(diskdoc))
        return Cls(diskdata)

    def update_host(self):

        """
        Enumerate local disks and partitions, update document.
        """

        ctx.uname
        ctx.hostname
        pass

    def local_doc(self):

        for disk_id, disk in self.data['catalog']['media'].items():

            for part in disk['partitions']:
                pass
