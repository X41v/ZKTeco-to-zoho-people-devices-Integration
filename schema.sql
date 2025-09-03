-- ZKTeco → Zoho Attendance Integration
-- MariaDB schema

CREATE DATABASE IF NOT EXISTS zk_attendance CHARACTER SET utf8mb4 COLLATE=utf8mb4_general_ci;
USE zk_attendance;

-- ------------------------------------------------------
-- Table: attendance_logs
-- ------------------------------------------------------
CREATE TABLE IF NOT EXISTS `attendance_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `name` varchar(100) DEFAULT NULL,
  `timestamp` datetime NOT NULL,
  `punch_type` tinyint(4) NOT NULL,
  `synced` tinyint(1) DEFAULT 0,
  `source` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ------------------------------------------------------
-- Table: raw_device_logs
-- ------------------------------------------------------
CREATE TABLE IF NOT EXISTS `raw_device_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `name` varchar(100) DEFAULT NULL,
  `timestamp` datetime NOT NULL,
  `status` enum('Check-In','Check-Out') NOT NULL,
  `device_ip` varchar(45) DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ------------------------------------------------------
-- Table: raw_zoho_logs
-- ------------------------------------------------------
CREATE TABLE IF NOT EXISTS `raw_zoho_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `timestamp` datetime NOT NULL,
  `punch_type` tinyint(1) NOT NULL,
  `source` varchar(50) DEFAULT 'zoho',
  `inserted_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_user_time` (`user_id`,`timestamp`,`punch_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
