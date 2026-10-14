"""Evidence-based keyword retrieval; never returns unapproved/canon records."""
import re
import time
from .policy import MEMORY_KINDS, retrievable

def tokens(text):
    words=set(re.findall(r'[A-Za-z0-9_]{2,}',text.lower()))
    for segment in re.findall(r'[\u4e00-\u9fff]+',text):
        words.update(segment[i:i+2] for i in range(len(segment)-1))
    return words-{'记得','喜欢','什么','我们','上次','可以','今天','我的','你的','一下','知道'}

class MemoryRetriever:
    def __init__(self, store, clock=time.monotonic, ttl=300):
        self.store, self.clock, self.ttl = store, clock, ttl
        self._revision = -1
        self._expires = 0
        self._indexed = ()

    def retrieve_with_revision(self, query, limit=8):
        # Only the snapshot read is a SQLite critical section. Tokenization and
        # ranking run outside it; immutable indexed data is shared for 5 minutes.
        with self.store.lock:
            revision = self.store.memory_revision
            if revision == self._revision and self.clock() < self._expires:
                indexed = self._indexed
                fresh = False
            else:
                rows = [r for r in self.store.all() if r['kind'] in MEMORY_KINDS and retrievable(r)]
                fresh = True
        if fresh:
            indexed = tuple((row, tokens(row.get('content', row.get('topic', '')))) for row in rows)
            with self.store.lock:
                if revision == self.store.memory_revision:
                    self._indexed, self._revision = indexed, revision
                    self._expires = self.clock() + self.ttl
        q = tokens(query)
        recall = any(w in query for w in ['你记得','还记得','我喜欢什么','我的偏好'])
        ranked = []
        for row, terms in indexed:
            score = len(q & terms)
            if recall and row['kind'] in {'profile_memory','relationship_memory','user_preference_memory'}: score += 1
            if score: ranked.append((score, row['updated_at'], row))
        ranked.sort(key=lambda item: (item[0], item[1]), reverse=True)
        return [dict(row) for _, _, row in ranked[:limit]], revision

    def retrieve(self, query, limit=8):
        return self.retrieve_with_revision(query, limit)[0]
