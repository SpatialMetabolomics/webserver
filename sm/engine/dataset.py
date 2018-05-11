import json
import logging

from sm.engine.errors import UnknownDSID
from sm.engine.queue import SM_DS_STATUS

logger = logging.getLogger('engine')


class DatasetStatus(object):
    """ Stage of dataset lifecycle """

    """ The dataset is just saved to the db """
    NEW = 'NEW'

    """ The dataset is queued for processing """
    QUEUED = 'QUEUED'

    """ The processing is in progress """
    STARTED = 'STARTED'

    """ The processing/reindexing finished successfully (most common) """
    FINISHED = 'FINISHED'

    """ An error occurred during processing """
    FAILED = 'FAILED'

    """ The records are being updated because of changed metadata """
    INDEXING = 'INDEXING'

    """ The dataset has been deleted """
    DELETED = 'DELETED'


class Dataset(object):
    """ Model class for representing a dataset """
    DS_SEL = ('SELECT name, input_path, upload_dt, metadata, config, status, is_public, mol_dbs '
              'FROM dataset WHERE id = %s')
    DS_UPD = ('UPDATE dataset set name=%s, input_path=%s, upload_dt=%s, metadata=%s, config=%s, status=%s, '
              'is_public=%s, mol_dbs=%s where id=%s')
    DS_CONFIG_SEL = 'SELECT config FROM dataset WHERE id = %s'
    DS_INSERT = ('INSERT INTO dataset (id, name, input_path, upload_dt, metadata, config, status, is_public, mol_dbs) '
                 'VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)')

    def __init__(self, id=None, name=None, input_path=None, upload_dt=None,
                 metadata=None, config=None, status=DatasetStatus.NEW,
                 is_public=True, mol_dbs=None):
        self.id = id
        self.name = name
        self.input_path = input_path
        self.upload_dt = upload_dt
        self.metadata = metadata
        self.config = config
        self.status = status
        self.is_public = is_public
        self.mol_dbs = mol_dbs

    def __str__(self):
        return str(self.__dict__)

    def __eq__(self, other):
        return self.__dict__ == other.__dict__

    def set_status(self, db, es, status_queue=None, status=None):
        self.status = status
        self.save(db, es, status_queue)

    @classmethod
    def load(cls, db, ds_id):
        r = db.select_one(cls.DS_SEL, ds_id)
        if r:
            ds = Dataset(ds_id)
            ds.name, ds.input_path, ds.upload_dt, ds.metadata, ds.config, ds.status, ds.is_public, ds.mol_dbs = r
        else:
            raise UnknownDSID('Dataset does not exist: {}'.format(ds_id))
        return ds

    def is_stored(self, db):
        r = db.select_one(self.DS_SEL, self.id)
        return True if r else False

    def save(self, db, es, status_queue=None):
        assert (self.id and self.name and self.input_path and self.upload_dt and self.config and self.status
                and self.is_public is not None and self.mol_dbs), self.__str__()
        row = (self.id, self.name, self.input_path, self.upload_dt.isoformat(' '),
               json.dumps(self.metadata), json.dumps(self.config), self.status,
               self.is_public, self.mol_dbs)
        if not self.is_stored(db):
            db.insert(self.DS_INSERT, [row])
        else:
            db.alter(self.DS_UPD, *(row[1:] + row[:1]))  # ds_id goes last in DS_UPD
        logger.info("Inserted into dataset table: %s, %s", self.id, self.name)

        es.sync_dataset(self.id)
        if status_queue:
            status_queue.publish({'ds_id': self.id, 'status': self.status})

    def to_queue_message(self):
        msg = {
            'ds_id': self.id,
            'ds_name': self.name,
            'input_path': self.input_path
        }
        email = self.metadata.get('Submitted_By', {}).get('Submitter', {}).get('Email', None)
        if email:
            msg['user_email'] = email.lower()
        return msg
