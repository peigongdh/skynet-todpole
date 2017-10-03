CREATE DATABASE todpole;

USE todpole;

DROP TABLE IF EXISTS `users`;

CREATE TABLE `users` (
    `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `uid` int(10) unsigned NOT NULL DEFAULT '0',
    `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
    `exp` int(10) unsigned NOT NULL DEFAULT '0',
    `created_at` timestamp NULL DEFAULT NULL,
    `updated_at` timestamp NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `users_uid_unique` (`uid`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

