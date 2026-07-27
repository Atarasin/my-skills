-- 现有单体商城的表结构（订单服务需要对接的既有系统）

CREATE TABLE users (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  username      VARCHAR(64)  NOT NULL UNIQUE,
  email         VARCHAR(128) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at    DATETIME     NOT NULL,
  updated_at    DATETIME     NOT NULL
);

CREATE TABLE user_contacts (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id    BIGINT      NOT NULL,
  channel    VARCHAR(16) NOT NULL,  -- 'sms' | 'email' | 'push'
  value      VARCHAR(128) NOT NULL,
  verified   TINYINT(1)  NOT NULL DEFAULT 0,
  created_at DATETIME    NOT NULL,
  INDEX idx_user_channel (user_id, channel)
);

CREATE TABLE products (
  id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  sku        VARCHAR(64)    NOT NULL UNIQUE,
  title      VARCHAR(255)   NOT NULL,
  price_cents BIGINT        NOT NULL,
  stock      INT            NOT NULL DEFAULT 0
);
