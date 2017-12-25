from datetime import datetime

from sqlalchemy import Column, Boolean, DateTime


class CardMixin(object):

    deleted = Column(Boolean, index=True, default=False)

    date_added = Column(DateTime, index=True, nullable=False)
    date_deleted = Column(DateTime)
    date_updated = Column(DateTime, index=True, nullable=False)

    def delete(self):
        self.deleted = True
        self.date_deleted = datetime.now()

    def init_defaults(self):
        if not self.date_added:
            self.date_updated = self.date_added = datetime.now()
        elif not self.date_updated:
            self.date_updated = datetime.now()

    keys = 'deleted date_added date_deleted date_updated'.split(' ')
