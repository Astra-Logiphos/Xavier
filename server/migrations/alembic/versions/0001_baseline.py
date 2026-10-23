"""基线 = schema_migrations v1（001_initial.sql 唯一结构来源）。

该 SQL 文件只含分号分隔的简单语句，因此按分号切分逐条执行；
不引入第二份结构定义。
"""
from pathlib import Path

from alembic import op

revision = '0001_baseline'
down_revision = None
branch_labels = None
depends_on = None

_SQL = (Path(__file__).resolve().parents[2]
        / '001_initial.sql').read_text(encoding='utf8')


def upgrade():
    for statement in _SQL.split(';'):
        if statement.strip():
            op.execute(statement)


def downgrade():
    op.execute('DROP INDEX IF EXISTS idx_kind')
    op.execute('DROP TABLE IF EXISTS model_usage')
    op.execute('DROP TABLE IF EXISTS settings')
    op.execute('DROP TABLE IF EXISTS records')
    op.execute('DROP TABLE IF EXISTS schema_migrations')
