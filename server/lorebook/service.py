def approved_lore(store):
    return [t for t in store.all('trait') if t.get('layer')=='canon_persona' and t.get('review_status')=='approved' and not t.get('paused')]
