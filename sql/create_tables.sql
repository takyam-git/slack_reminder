-- DROP TABLE IF EXISTS `users`;

CREATE TABLE IF NOT EXISTS `users` (
  `id`           INTEGER   UNSIGNED NOT NULL    AUTO_INCREMENT,
  `url`          VARCHAR(255)       NOT NULL,
  `team`         VARCHAR(255)       NOT NULL,
  `name`         VARCHAR(255)       NOT NULL,
  `team_id`      VARCHAR(128)       NOT NULL,
  `user_id`      VARCHAR(128)       NOT NULL,
  `access_token` VARCHAR(1024)      NOT NULL,
  `scope`        VARCHAR(128)       NOT NULL,
  `updated_at`   TIMESTAMP          NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_at`   DATETIME           NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY (`team_id`, `user_id`)
);

-- DROP TABLE IF EXISTS `events`;

CREATE TABLE IF NOT EXISTS `events` (
  `id`                INTEGER   UNSIGNED    NOT NULL    AUTO_INCREMENT,
  `user_id`           INTEGER   UNSIGNED    NOT NULL,
  `name`              VARCHAR(255)          NOT NULL,
  `description`       MEDIUMTEXT            NULL        DEFAULT '',
  `notification_type` ENUM('dm', 'channel') NOT NULL,
  `channel_name`      VARCHAR(255)          NULL        DEFAULT NULL,
  `user_name`         VARCHAR(255)          NULL        DEFAULT NULL,
  `timing`            DATETIME              NOT NULL,
  `is_completed`      TINYINT               NOT NULL    DEFAULT 0,
  'error'             VARCHAR(255)          NULL        DEFAULT NULL,
  `updated_at`        TIMESTAMP             NOT NULL    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_at`        DATETIME              NOT NULL,
  PRIMARY KEY (`id`)
);
CREATE INDEX idx_events_user_id ON `events` (`user_id`);
CREATE INDEX idx_events_user_completed_id ON `events` (`user_id`, `is_completed`);
CREATE INDEX idx_events_completed ON `events` (`is_completed`);
CREATE INDEX idx_events_completed_timing ON `events` (`is_completed`, `timing`);
ALTER TABLE `events` ADD FOREIGN KEY (`user_id`) REFERENCES `users` (`id`);