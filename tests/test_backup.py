import copy
import unittest
import test_api

class BackupTests(unittest.TestCase):
    setUp=test_api.ApiTests.setUp
    tearDown=test_api.ApiTests.tearDown
    call=test_api.ApiTests.call
    create=test_api.ApiTests.create
    def test_export_clear_import_preserves_ids_and_all_settings(self):
        self.call('PATCH','/settings',{'save_conversations':True,'reminders_enabled':True,'language':'en-US'})
        self.create('/chat',{'text':'今天一起看小鸟'})
        memory=self.create('/memories',{'content':'喜欢星空','consent':True})
        self.create('/checkins',{'category':'学习'})
        self.app.store.reserve_call('2026-01-01',10)
        exported=self.call('GET','/data/export')[1]
        self.assertIn('reminders_enabled',exported['settings'])
        self.assertNotIn('test-token',str(exported))
        self.call('DELETE','/data',{'confirmation':'DELETE_ALL'})
        self.assertEqual(self.call('POST','/data/import',exported)[0],200)
        restored=self.call('GET','/data/export')[1]
        for key in ['records','settings','model_usage']:self.assertEqual(restored[key],exported[key])
        self.assertEqual(self.app.store.get(memory['id'])['content'],'喜欢星空')
        self.assertEqual(len(self.call('GET','/conversations')[1]['items']),1)
        self.assertEqual(self.call('GET','/status')[0],200)
    def test_invalid_restore_never_changes_database(self):
        original=self.call('GET','/data/export')[1]
        for change in ['duplicate','reference','credentials','nan']:
            data=copy.deepcopy(original)
            if change=='duplicate':data['records'].append(data['records'][0])
            if change=='reference':data['settings']['active_persona']='missing'
            if change=='credentials':data['settings']['api_key']='private'
            if change=='nan':data['records'][0]['bad']=float('nan')
            self.assertEqual(self.call('POST','/data/import',data)[0],400,change)
            self.assertEqual(self.call('GET','/data/export')[1]['records'],original['records'])
    def test_large_valid_backup_exceeds_old_64k_limit(self):
        data=self.call('GET','/data/export')[1]
        data['records'][0]['local_note']='x'*70000
        self.assertEqual(self.call('POST','/data/import',data)[0],200)
