"""数据库结构引导。001_initial.sql 始终是唯一结构来源（schema_migrations v1）。

可选 alembic：安装了 alembic 的开发/CI 环境中，全新数据库走版本化迁移
（0001_baseline 执行同一份 SQL 并写入 alembic_version），已存在的数据库首次
接入时自动 stamp 到基线（不改动数据）。离线打包运行时未携带 alembic，直接
执行同一份 SQL，两种路径得到的结构完全一致。alembic 复用本函数传入的
sqlite 连接（StaticPool 单连接），不开第二个连接，避免 Windows 文件锁。

现有库升级方法：无需手动操作——后端下次启动检测到 records 表已存在且无
alembic_version 时自动 stamp；之后的结构变更以新的 alembic revision 发布。
"""
from pathlib import Path

SCHEMA_FILE = Path(__file__).with_name('001_initial.sql')
BASELINE_REVISION = '0001_baseline'


def _alembic_available():
    try:
        import alembic  # noqa: F401
        return True
    except ImportError:
        return False


def _has_table(db, name):
    return db.execute(
        'SELECT 1 FROM sqlite_master WHERE type=\'table\' AND name=?',
        (name,)).fetchone() is not None


def _run_alembic(db, target, stamp=False):
    from alembic import command
    from alembic.config import Config
    from sqlalchemy import create_engine
    from sqlalchemy.pool import StaticPool

    cfg = Config()
    cfg.set_main_option('script_location',
                        str(Path(__file__).with_name('alembic')))
    engine = create_engine('sqlite://', creator=lambda: db,
                           poolclass=StaticPool)
    cfg.attributes['connection'] = engine.connect()
    try:
        if stamp:
            command.stamp(cfg, target)
        else:
            command.upgrade(cfg, target)
    finally:
        cfg.attributes['connection'].close()


def initialize_schema(db, path):
    """为本连接创建或登记结构。返回实际采用的引导模式字符串。"""
    if path == ':memory:' or not _alembic_available():
        db.executescript(SCHEMA_FILE.read_text(encoding='utf8'))
        return 'sql-baseline'
    if _has_table(db, 'records'):
        if _has_table(db, 'alembic_version'):
            return 'already-managed'
        _run_alembic(db, BASELINE_REVISION, stamp=True)
        return 'stamped-existing'
    _run_alembic(db, 'head')
    return 'alembic-baseline'
