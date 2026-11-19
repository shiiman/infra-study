-- POSTGRES_DB=test_db で作られたデータベースの中で実行される

CREATE TABLE IF NOT EXISTS users (
  id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name VARCHAR(255) NOT NULL
);

INSERT INTO users (name) VALUES ('infra'), ('study');
