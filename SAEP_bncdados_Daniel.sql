DROP TABLE IF EXISTS historico_tarefas CASCADE;
DROP TABLE IF EXISTS tarefas CASCADE;
DROP TABLE IF EXISTS colaboradores CASCADE;



CREATE TABLE colaboradores(
id SERIAL PRIMARY KEY,
nome VARCHAR(150) NOT NULL,
email VARCHAR(150) NOT NULL UNIQUE,
senha VARCHAR(100) NOT NULL,
ativo BOOLEAN DEFAULT TRUE
);


CREATE TABLE tarefas (
id SERIAL PRIMARY KEY,
titulo VARCHAR(150) NOT NULL,
categoria VARCHAR(100) NOT NULL,
descrição TEXT,
data_entrega DATE NOT NULL,
data_criação TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
status VARCHAR(30) DEFAULT 'Pendente',
colaborador_id INTEGER NOT NULL,

CONSTRAINT fk_colaborador
FOREIGN KEY (colaborador_id)
REFERENCES colaboradores(id),

CONSTRAINT chk_status
CHECK (status IN ('Pendente','Em andamento', 'Concluida', 'Cancelada'))
);


CREATE TABLE historico_tarefas (
id SERIAL PRIMARY KEY,
tarefa_id INTEGER NOT NULL,
descricao VARCHAR(255) NOT NULL,
data_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

CONSTRAINT fk_tarefa
FOREIGN KEY (tarefa_id)
REFERENCES tarefas(id)
);




INSERT INTO colaboradores (nome, email, senha, ativo)
VALUES
('Daniel', 'daniel@gmail.com', '123456', 'TRUE'),
('Maria', 'maria@gmail.com', '654321', 'TRUE'),
('Enzo', 'enzo@gmail.com', '324156', 'FALSE');


CREATE OR REPLACE FUNCTION fn_validar_tarefa()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN 
--verifica se o colaborador esta ativo
IF NOT EXISTS (
SELECT 1
FROM colaboradores
WHERE id = NEW.colaborador_id
AND ativo = TRUE
) THEN
RAISE EXCEPTION
'ERRO: colaborador inexistente ou inativo!';
END IF;
--registra automaticamente a data de criacao
NEW.data_criacao := CURRENT_TIMESTAMP;
RETURN NEW;
END;
$$;


CREATE TRIGGER trg_validar_tarefa
BEFORE INSERT ON tarefas
FOR EACH ROW
EXECUTE FUNCTION fn_validar_tarefa();



CREATE OR REPLACE FUNCTION fn_registrar_historico()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO historico_tarefas
    (tarefa_id, descricao)
    VALUES
    (NEW.id, 'Tarefa criada: ' || NEW.titulo);

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_registrar_historico
AFTER INSERT ON tarefas
FOR EACH ROW
EXECUTE FUNCTION fn_registrar_historico();

ALTER TABLE tarefas
ADD COLUMN descricao TEXT;


ALTER TABLE tarefas
ADD COLUMN data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP;


INSERT INTO tarefas
(titulo, categoria, descricao, data_entrega, status, colaborador_id)
VALUES
(
    'Criar relatorio financeiro',
    'Financeiro',
    'Elaborar relatorio mensal',
    '2026-11-25',
    'Pendente',
    1
),
(
    'Desenvolver site',
    'Tecnologia',
    'Criar pagina institucional',
    '2026-11-22',
    'Em andamento',
    2
),
(
    'Organizar documentos',
    'Administrativo',
    'Organizar arquivos da empresa',
    '2026-12-05',
    'Pendente',
    1
);




CREATE OR REPLACE VIEW vw_painel_principal AS
SELECT
    c.nome AS colaborador,
    t.titulo AS tarefa,
    t.categoria,
    t.data_entrega AS prazo_entrega,
    t.status
FROM tarefas t
INNER JOIN colaboradores c
    ON t.colaborador_id = c.id;

-- ==========================================
-- 8. FUNCTION DE BUSCA DE COLABORADORES
-- ==========================================

CREATE OR REPLACE FUNCTION fn_buscar_colaboradores(
    termo_busca TEXT
)
RETURNS TABLE (
    id INTEGER,
    nome VARCHAR(150),
    email VARCHAR(150),
    ativo BOOLEAN
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.nome,
        c.email,
        c.ativo
    FROM colaboradores c
    WHERE c.nome ILIKE '%' || termo_busca || '%'
       OR c.email ILIKE '%' || termo_busca || '%';
END;
$$;

-- ==========================================
-- 9. VIEW DO CRONOGRAMA DE PRAZOS
-- ==========================================

CREATE OR REPLACE VIEW vw_cronograma_prazos AS
SELECT
    t.id AS tarefa_id,
    t.titulo AS tarefa,
    t.status,
    t.data_entrega,
    (t.data_entrega - CURRENT_DATE) AS dias_restantes,
    c.nome AS responsavel
FROM tarefas t
INNER JOIN colaboradores c
    ON t.colaborador_id = c.id;

-- ==========================================
-- 10. CONSULTAS PARA TESTAR O SISTEMA
-- ==========================================

-- Visualizar todos os colaboradores
SELECT * FROM colaboradores;

-- Visualizar todas as tarefas
SELECT * FROM tarefas;

-- Visualizar historico
SELECT * FROM historico_tarefas;

-- Testar painel principal
SELECT * FROM vw_painel_principal;

-- Testar busca de colaboradores
SELECT * FROM fn_buscar_colaboradores('Daniel');

-- Testar cronograma ordenado por urgencia
SELECT *
FROM vw_cronograma_prazos
ORDER BY data_entrega ASC, tarefa_id ASC;

-- Testar se o trigger bloqueia colaborador inativo
-- Esta insercao deve gerar um erro:
-- INSERT INTO tarefas
-- (titulo, categoria, data_entrega, colaborador_id)
-- VALUES ('Teste', 'Administrativo', '2026-12-10', 3);