"""数据库结构引导。001_initial.sql 始终是唯一结构来源（schema_migrations v1）。

可选 alembic：安装了 alembic 的开发/CI 环境中，全新数据库走版本化迁移
（0001_baseline 执行同一份 SQL 并写入 alembic_version），已存在的数据库首次
接入时自动 stamp 到基线（不改动数据）。离线打包运行时未携带 alembic，直接
执行同一份 SQL，两种路径得到的结构完全一致。

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


def initialize_schema(db, path):
    """为本连接创建或登记结构。返回实际采用的引导模式字符串。"""
    if path == ':memory:' or not _alembic_available():
        db.executescript(SCHEMA_FILE.read_text(encoding='utf8'))
        return 'sql-baseline'
    from alembic.config import Config
    from alembic import command
    cfg = Config()
    cfg.set_main_option('script_location',
                        str(Path(__file__).with_name('alembic')))
    cfg.set_main_option('sqlalchemy.url',
                        'sqlite:///' + Path(path).resolve().as_posix())
    if _has_table(db, 'records'):
        if _has_table(db, 'alembic_version'):
            return 'already-managed'
        command.stamp(cfg, BASELINE_REVISION)
        return 'stamped-existing'
    command.upgrade(cfg, 'head')
    return 'alembic-baseline'
