create table if not exists dim.uf (
    uf_id smallint generated always as identity primary key,
    sigla char(2) not null unique,
    nome text not null,
    codigo_ibge integer
);

insert into dim.uf (sigla, nome, codigo_ibge)
values ('DF', 'Distrito Federal', 53)
on conflict (sigla) do update
set nome = excluded.nome,
    codigo_ibge = excluded.codigo_ibge;
