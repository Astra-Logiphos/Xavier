"""Alembic 环境：目标结构元数据为空（结构唯一来源是 001_initial.sql，
迁移文件手工执行该 SQL，不用 autogenerate 差异）。

优先复用调用方通过 config.attributes['connection'] 传入的连接
（本地 SQLite 单连接模式，避免第二个连接在 Windows 上锁文件）。
"""
from alembic import context

config = context.config
target_metadata = None


def run_migrations_offline():
    context.configure(url=config.get_main_option('sqlalchemy.url'),
                      literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online():
    connectable = config.attributes.get('connection', None)
    if connectable is not None:
        context.configure(connection=connectable,
                          target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()
        return
    from sqlalchemy import engine_from_config
    engine = engine_from_config(
        config.get_section(config.config_ini_section),
        prefix='sqlalchemy.')
    with engine.connect() as connection:
        context.configure(connection=connection,
                          target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
