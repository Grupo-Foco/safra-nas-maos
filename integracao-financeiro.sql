-- ═══════════════════════════════════════════════════════════════
-- INTEGRAÇÃO SAFRA NAS MÃOS  ←  GESTÃO FINANCEIRA (dashboard completo)
-- Rode UMA VEZ no SQL Editor do Projeto do Grupo Foco (Supabase).
-- (Pode rodar de novo por cima — é idempotente.)
--
-- NÃO altera a tabela lancamentos nem suas políticas: o financeiro
-- continua igual. Só ADICIONA uma leitura SEGURA que devolve os
-- gastos de TODAS as categorias, APENAS da fazenda de que a pessoa
-- é membro no Safra. Quem pode abrir o módulo Financeiro no Safra é
-- controlado por acesso (poucas pessoas), como o Maquinário.
--
-- OBS: diferente de safra_gastos_manut (diesel), esta função devolve
-- TAMBÉM salário/pró-labore. Por isso o acesso ao módulo Financeiro
-- deve ser liberado só a quem pode ver a folha (dono/gestores).
-- ═══════════════════════════════════════════════════════════════

-- 1) Garante a coluna de-para (já existe se você rodou a do diesel)
alter table safra_fazendas add column if not exists fin_fazenda text;

-- Completa o de-para das fazendas conhecidas (idempotente — só preenche vazios)
update safra_fazendas set fin_fazenda='SANTA ANGELINA'
  where lower(nome) like '%santa angelina%' and fin_fazenda is null;
update safra_fazendas set fin_fazenda='MAYARA'
  where lower(nome) like '%mayara%'         and fin_fazenda is null;
update safra_fazendas set fin_fazenda='LAGEADO'
  where (lower(nome) like '%lajeado%' or lower(nome) like '%lageado%' or lower(nome) like '%edealina%')
    and fin_fazenda is null;
update safra_fazendas set fin_fazenda='SÃO BENTO'
  where lower(nome) like '%bento%'          and fin_fazenda is null;
update safra_fazendas set fin_fazenda='BRASIL'
  where lower(nome) like '%brasil%'         and fin_fazenda is null;

-- 2) Função de leitura segura — TODAS as categorias, da fazenda do membro.
--    Se fin_fazenda não estiver preenchido (fazenda nova), deriva do nome,
--    então fazendas criadas depois já funcionam sem rodar o SQL de novo.
drop function if exists safra_gastos(text);
create or replace function safra_gastos(p_fazenda_id text)
returns table(
  data date, vencimento date, status text, safra text, cultura text,
  categoria text, historico text, fornecedor text, forma text, valor numeric
)
language plpgsql security definer set search_path = public as $$
declare v_fin text; v_nome text;
begin
  -- só membro da fazenda no Safra pode ler
  if not safra_e_membro(p_fazenda_id) then return; end if;

  select fin_fazenda, nome into v_fin, v_nome
    from safra_fazendas where id = p_fazenda_id;
  if v_nome is null then return; end if;

  -- fallback: deriva o nome no financeiro quando o de-para está vazio
  if v_fin is null then
    v_fin := case
      when lower(v_nome) like '%santa angelina%' then 'SANTA ANGELINA'
      when lower(v_nome) like '%mayara%'         then 'MAYARA'
      when lower(v_nome) like '%lajeado%' or lower(v_nome) like '%lageado%'
        or lower(v_nome) like '%edealina%'       then 'LAGEADO'
      when lower(v_nome) like '%bento%'          then 'SÃO BENTO'
      when lower(v_nome) like '%brasil%'         then 'BRASIL'
      else upper(v_nome)
    end;
  end if;
  if v_fin is null then return; end if;

  return query
    select l.data_doc, l.vencimento, l.status, l.safra, l.cultura,
           l.cg, l.historico, l.fornecedor, l.forma_pagamento, l.valor
    from lancamentos l
    where l.fazenda = v_fin
    order by l.vencimento desc nulls last, l.data_doc desc nulls last;
end $$;

grant execute on function safra_gastos(text) to authenticated;

select 'Integração financeiro pronta.' as status,
       (select count(*) from safra_fazendas where fin_fazenda is not null) as fazendas_mapeadas;
