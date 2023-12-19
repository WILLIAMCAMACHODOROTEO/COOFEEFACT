-- phpMyAdmin SQL Dump
-- version 4.9.2
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1:3306
-- Tiempo de generación: 10-08-2020 a las 02:30:38
-- Versión del servidor: 8.0.18
-- Versión de PHP: 7.3.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET AUTOCOMMIT = 0;
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `facturacion`
--

DELIMITER $$
--
-- Procedimientos
--
DROP PROCEDURE IF EXISTS `actualizar_precio_producto`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `actualizar_precio_producto` (`n_cantidad` INT, `n_precio` DECIMAL(10,2), `codigo` INT)  BEGIN
    	DECLARE nueva_existencia int;
        DECLARE nuevo_total  decimal(10,2);
        DECLARE nuevo_precio decimal(10,2);
        
        DECLARE cant_actual int;
        DECLARE pre_actual decimal(10,2);
        
        DECLARE actual_existencia int;
        DECLARE actual_precio decimal(10,2);
                
        SELECT precio,existencia INTO actual_precio,actual_existencia FROM producto WHERE codproducto = codigo;
        
        SET nueva_existencia = actual_existencia + n_cantidad;
        SET nuevo_total = (actual_existencia * actual_precio) + (n_cantidad * n_precio);
        SET nuevo_precio = nuevo_total / nueva_existencia;
        
        UPDATE producto SET existencia = nueva_existencia, precio = nuevo_precio WHERE codproducto = codigo;
        
        SELECT nueva_existencia,nuevo_precio;    
        
    END$$

DROP PROCEDURE IF EXISTS `add_detalle_temp`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `add_detalle_temp` (`codigo` INT, `cantidad` INT, `token_user` VARCHAR(50))  BEGIN

        DECLARE precio_actual decimal(10,2);
        SELECT precio INTO precio_actual FROM producto WHERE codproducto = codigo;

        INSERT INTO detalle_temp(token_user,codproducto,cantidad,precio_venta) VALUES(token_user,codigo,cantidad,precio_actual);

        SELECT tmp.correlativo, tmp.codproducto,p.descripcion,tmp.cantidad,tmp.precio_venta FROM detalle_temp tmp
        INNER JOIN producto p
        ON tmp.codproducto = p.codproducto
        WHERE tmp.token_user = token_user;

    END$$

DROP PROCEDURE IF EXISTS `anular_factura`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `anular_factura` (IN `no_factura` INT)  BEGIN
    	DECLARE existe_factura int;
        DECLARE registros int;
        DECLARE a int;
        
        DECLARE cod_producto int;
        DECLARE cant_producto int;
        DECLARE existencia_actual int;
        DECLARE nueva_existencia int;
        
        SET existe_factura = (SELECT COUNT(*) FROM factura WHERE nofactura = no_factura and estatus = 1);
        
        IF existe_factura > 0 THEN
        	CREATE TEMPORARY TABLE tbl_tmp (
                id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
                cod_prod BIGINT,
                cant_prod int);
                
                SET a = 1;
                
                SET registros = (SELECT COUNT(*) FROM detallefactura WHERE nofactura = no_factura);
                
                IF registros > 0 THEN
                	INSERT INTO tbl_tmp(cod_prod,cant_prod) SELECT codproducto,cantidad FROM detallefactura WHERE nofactura = no_factura;
                    
                    WHILE a <= registros DO
                    	SELECT cod_prod,cant_prod INTO cod_producto,cant_producto FROM tbl_tmp WHERE id = a;
                        SELECT existencia INTO existencia_actual FROM producto WHERE codproducto = cod_producto;
                        SET nueva_existencia = existencia_actual + cant_producto;
                        UPDATE producto SET existencia = nueva_existencia WHERE codproducto = cod_producto;
                        
                        SET a=a+1;
                    END WHILE;
                    
                    UPDATE factura SET estatus = 2 WHERE nofactura = no_factura;
                    DROP TABLE tbl_tmp;
                    SELECT * from factura WHERE nofactura = no_factura;
                   
                END IF;

        ELSE
        	SELECT 0 factura;
        END IF;
        
    END$$

DROP PROCEDURE IF EXISTS `dataDashboard`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `dataDashboard` ()  BEGIN
		
        DECLARE usuarios int;
        DECLARE clientes int;
        DECLARE proveedores int;
        DECLARE productos int;
        DECLARE ventas int;
        
        SELECT COUNT(*) INTO usuarios FROM usuario WHERE estatus != 10;
        SELECT COUNT(*) INTO clientes FROM cliente WHERE estatus != 10;
        SELECT COUNT(*) INTO proveedores FROM proveedor WHERE estatus != 10;
        SELECT COUNT(*) INTO productos FROM producto WHERE estatus != 10;
        SELECT COUNT(*) INTO ventas FROM factura WHERE fecha > CURDATE() AND estatus != 10;
        
        SELECT usuarios,clientes,proveedores,productos,ventas;

    END$$

DROP PROCEDURE IF EXISTS `del_detalle_temp`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `del_detalle_temp` (`id_detalle` INT, `token` VARCHAR(50))  BEGIN
        DELETE FROM detalle_temp WHERE correlativo = id_detalle;

        SELECT tmp.correlativo, tmp.codproducto,p.descripcion,tmp.cantidad,tmp.precio_venta FROM detalle_temp tmp
        INNER JOIN producto p
        ON tmp.codproducto = p.codproducto
        WHERE tmp.token_user = token;
    END$$

DROP PROCEDURE IF EXISTS `procesar_venta`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `procesar_venta` (`cod_usuario` INT, `cod_cliente` INT, `token` VARCHAR(50))  BEGIN
		DECLARE factura INT;

        DECLARE registros INT;
        DECLARE total DECIMAL(10,2);

        DECLARE nueva_existencia int;
        DECLARE existencia_actual int;

        DECLARE tmp_cod_producto int;
        DECLARE tmp_cant_producto int;
        DECLARE a INT;
        SET a = 1;
        
        CREATE TEMPORARY TABLE tbl_tmp_tokenuser (
                id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
                cod_prod BIGINT,
                cant_prod int);
                
        SET registros = (SELECT COUNT(*) FROM detalle_temp WHERE token_user = token);
        
        IF registros > 0 THEN
        	INSERT INTO tbl_tmp_tokenuser(cod_prod,cant_prod) SELECT codproducto,cantidad FROM detalle_temp WHERE token_user = token;
            
            INSERT INTO factura(usuario,codcliente) VALUES(cod_usuario,cod_cliente);
            SET factura = LAST_INSERT_ID();
            
            INSERT INTO detallefactura(nofactura,codproducto,cantidad,precio_venta) SELECT (factura) as nofactura, codproducto,cantidad,precio_venta FROM detalle_temp WHERE token_user = token;
            
            WHILE a <= registros DO
            	SELECT cod_prod,cant_prod INTO tmp_cod_producto,tmp_cant_producto FROM tbl_tmp_tokenuser WHERE id = a;
                SELECT existencia INTO existencia_actual FROM producto WHERE codproducto = tmp_cod_producto;
                
                SET nueva_existencia = existencia_actual - tmp_cant_producto;
                UPDATE producto SET existencia = nueva_existencia WHERE codproducto = tmp_cod_producto;
                
                SET a=a+1;
            	
            END WHILE;
            
            SET total = (SELECT SUM(cantidad * precio_venta) FROM detalle_temp WHERE token_user = token);
            UPDATE factura SET totalfactura = total WHERE nofactura = factura;
            DELETE FROM detalle_temp WHERE token_user = token;
            TRUNCATE TABLE tbl_tmp_tokenuser;
            SELECT * FROM factura WHERE nofactura = factura;
        ELSE
        	SELECT 0;
        END IF;
    END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `cliente`
--

DROP TABLE IF EXISTS `cliente`;
CREATE TABLE IF NOT EXISTS `cliente` (
  `idcliente` int(11) NOT NULL AUTO_INCREMENT,
  `nit` int(11) DEFAULT NULL,
  `nombre` varchar(80) DEFAULT NULL,
  `telefono` bigint(20) DEFAULT NULL,
  `direccion` text,
  `dateadd` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `usuario_id` int(11) NOT NULL,
  `estatus` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`idcliente`),
  KEY `usuario_id` (`usuario_id`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `cliente`
--

INSERT INTO `cliente` (`idcliente`, `nit`, `nombre`, `telefono`, `direccion`, `dateadd`, `usuario_id`, `estatus`) VALUES
(1, 0, 'CF', 878766787, 'Guatemala, Guatemala', '2018-02-15 21:55:51', 1, 1),
(2, 87654321, 'Marta Gonzales', 34343434, 'Calzada Buena Vista', '2018-02-15 21:57:03', 1, 1),
(3, 0, 'Elena HernÃ¡ndez', 987897987, 'Guatemala, Chimaltenango', '2018-02-15 21:59:20', 2, 0),
(4, 0, 'Julio Maldonado', 908098979, 'Avenida las Americas Zona 14', '2018-02-15 22:00:31', 3, 0),
(5, 0, 'Helen', 98789798, 'Guatemala', '2018-02-18 10:53:53', 1, 1),
(6, 0, 'Juan', 7987987, 'Chimaltenango', '2018-02-18 10:56:44', 1, 0),
(7, 12345, 'Jorge Maldonado', 2147483647, 'Colonia la Flores', '2018-02-18 11:10:07', 1, 1),
(8, 0, 'Marta Cabrera', 987987987, 'Guatemala', '2018-02-18 11:11:40', 2, 1),
(9, 79879879, 'Julio Estrada', 897987987, 'Avenida Elena', '2018-02-18 11:13:23', 3, 1),
(10, 2147483647, 'Roberto Morazan', 2147483647, 'Chimaltenango, Guatemala', '2018-03-04 19:17:22', 1, 1),
(11, 898798798, 'Rosa Pineda', 987998788, 'Ciudad Quetzal', '2018-03-04 19:17:45', 1, 1),
(12, 0, 'Angel Molina', 2147483647, 'Calzada Buena Vista', '2018-03-04 19:18:21', 1, 1),
(13, 567554566, 'Fernando Ovalle', 78978787, 'Avenida las AmÃ©ricas', '2019-01-16 00:42:36', 1, 1),
(14, 898989898, 'Roberto Cabrera Ovalle', 89098900, 'Ciudad', '2019-01-16 22:19:19', 1, 1),
(15, 2147483647, 'Alfredo Pineda', 890989009, 'Ciudad Guatemal', '2019-01-16 22:24:13', 1, 0),
(16, 34343434, 'Julio Pineda', 79879878, 'Ciudad Guatemal', '2019-01-16 22:25:58', 1, 1),
(17, 7678687, 'Juan', 79789798, 'Ciudad', '2019-01-17 00:05:40', 1, 1),
(18, 8897987, 'Jorege Francisco Arevalo', 7897990, 'Avenida La Castellana, Ciudad', '2019-06-01 21:50:39', 1, 1),
(19, 4567899, 'Jorge Misael Morales', 45785966, 'Ciudad Actual', '2019-07-25 08:03:21', 1, 1),
(20, 2147483647, 'Julieta Catro', 46546546554554, 'Ciudad', '2020-08-09 20:22:34', 1, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `configuracion`
--

DROP TABLE IF EXISTS `configuracion`;
CREATE TABLE IF NOT EXISTS `configuracion` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `nit` varchar(20) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `razon_social` varchar(100) NOT NULL,
  `telefono` bigint(20) NOT NULL,
  `email` varchar(200) NOT NULL,
  `direccion` text NOT NULL,
  `iva` decimal(10,2) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `configuracion`
--

INSERT INTO `configuracion` (`id`, `nit`, `nombre`, `razon_social`, `telefono`, `email`, `direccion`, `iva`) VALUES
(1, '123123123', 'PC Servicios SA', 'Ventas SA', 12121212, 'info@abelosh.com', 'Guatemala, Guatemala', '12.00');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detallefactura`
--

DROP TABLE IF EXISTS `detallefactura`;
CREATE TABLE IF NOT EXISTS `detallefactura` (
  `correlativo` bigint(11) NOT NULL AUTO_INCREMENT,
  `nofactura` bigint(11) DEFAULT NULL,
  `codproducto` int(11) DEFAULT NULL,
  `cantidad` int(11) DEFAULT NULL,
  `precio_venta` decimal(10,2) DEFAULT NULL,
  PRIMARY KEY (`correlativo`),
  KEY `codproducto` (`codproducto`),
  KEY `nofactura` (`nofactura`)
) ENGINE=InnoDB AUTO_INCREMENT=81 DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `detallefactura`
--

INSERT INTO `detallefactura` (`correlativo`, `nofactura`, `codproducto`, `cantidad`, `precio_venta`) VALUES
(1, 1, 12, 1, '250.00'),
(2, 1, 11, 2, '450.00'),
(3, 1, 6, 1, '2462.96'),
(4, 2, 8, 1, '150.00'),
(5, 2, 5, 2, '416.67'),
(7, 3, 8, 1, '150.00'),
(8, 3, 10, 1, '240.00'),
(9, 3, 12, 1, '250.00'),
(10, 4, 2, 1, '1530.00'),
(11, 5, 5, 1, '416.67'),
(12, 5, 3, 1, '220.00'),
(14, 6, 6, 1, '2462.96'),
(15, 7, 3, 1, '220.00'),
(16, 7, 4, 1, '10000.00'),
(17, 7, 7, 1, '2140.00'),
(18, 7, 9, 1, '2500.00'),
(22, 8, 3, 1, '220.00'),
(23, 8, 1, 1, '114.71'),
(25, 9, 3, 1, '220.00'),
(26, 9, 6, 1, '2462.96'),
(28, 10, 4, 2, '10000.00'),
(29, 10, 3, 1, '220.00'),
(31, 11, 5, 1, '416.67'),
(32, 11, 7, 1, '2140.00'),
(34, 12, 1, 1, '114.71'),
(35, 13, 2, 1, '1530.00'),
(36, 14, 4, 2, '10000.00'),
(37, 14, 2, 1, '1530.00'),
(39, 15, 4, 2, '10000.00'),
(40, 15, 5, 1, '416.67'),
(42, 16, 4, 2, '10000.00'),
(43, 16, 6, 1, '2462.96'),
(45, 17, 5, 1, '416.67'),
(46, 18, 1, 1, '114.71'),
(47, 19, 1, 1, '114.71'),
(48, 20, 8, 1, '150.00'),
(49, 21, 2, 1, '1530.00'),
(50, 22, 4, 2, '10000.00'),
(51, 22, 3, 1, '220.00'),
(53, 23, 2, 1, '1530.00'),
(54, 23, 7, 1, '2140.00'),
(55, 24, 11, 2, '450.00'),
(56, 24, 12, 1, '250.00'),
(57, 25, 4, 2, '10000.00'),
(58, 25, 5, 2, '416.67'),
(59, 26, 1, 1, '114.71'),
(60, 26, 8, 2, '150.00'),
(61, 26, 5, 2, '416.67'),
(62, 27, 5, 1, '416.67'),
(63, 27, 10, 2, '240.00'),
(64, 27, 2, 1, '1530.00'),
(65, 28, 3, 1, '220.00'),
(66, 28, 5, 2, '416.67'),
(67, 29, 5, 1, '416.67'),
(68, 29, 10, 1, '240.00'),
(69, 29, 8, 1, '150.00'),
(70, 30, 2, 3, '1530.00'),
(71, 30, 4, 1, '10000.00'),
(72, 30, 7, 3, '2140.00'),
(73, 31, 2, 1, '1530.00'),
(74, 31, 3, 1, '220.00'),
(75, 31, 9, 1, '2500.00'),
(76, 31, 6, 1, '2462.96'),
(77, 31, 5, 5, '416.67'),
(78, 32, 4, 1, '10000.00'),
(79, 32, 10, 3, '240.00'),
(80, 32, 3, 1, '220.00');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_temp`
--

DROP TABLE IF EXISTS `detalle_temp`;
CREATE TABLE IF NOT EXISTS `detalle_temp` (
  `correlativo` int(11) NOT NULL AUTO_INCREMENT,
  `token_user` varchar(50) NOT NULL,
  `codproducto` int(11) NOT NULL,
  `cantidad` int(11) NOT NULL,
  `precio_venta` decimal(10,2) NOT NULL,
  PRIMARY KEY (`correlativo`),
  KEY `nofactura` (`token_user`),
  KEY `codproducto` (`codproducto`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `entradas`
--

DROP TABLE IF EXISTS `entradas`;
CREATE TABLE IF NOT EXISTS `entradas` (
  `correlativo` int(11) NOT NULL AUTO_INCREMENT,
  `codproducto` int(11) NOT NULL,
  `fecha` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `cantidad` int(11) NOT NULL,
  `precio` decimal(10,2) NOT NULL,
  `usuario_id` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`correlativo`),
  KEY `codproducto` (`codproducto`)
) ENGINE=InnoDB AUTO_INCREMENT=28 DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `entradas`
--

INSERT INTO `entradas` (`correlativo`, `codproducto`, `fecha`, `cantidad`, `precio`, `usuario_id`) VALUES
(1, 1, '0000-00-00 00:00:00', 150, '110.00', 1),
(2, 2, '2018-04-05 00:12:15', 100, '1500.00', 1),
(3, 3, '2018-04-07 22:48:23', 200, '250.00', 9),
(4, 4, '2018-09-08 22:28:50', 50, '10000.00', 1),
(5, 5, '2018-09-08 22:34:38', 100, '500.00', 1),
(6, 6, '2018-09-08 22:35:27', 8, '2000.00', 1),
(7, 7, '2018-12-02 00:15:09', 75, '2200.00', 1),
(8, 8, '2018-12-02 00:39:42', 75, '160.00', 1),
(9, 3, '2018-12-06 01:16:13', 100, '160.00', 1),
(10, 8, '2018-12-06 01:25:05', 100, '125.00', 1),
(11, 6, '2018-12-06 01:36:49', 100, '2500.00', 1),
(12, 7, '2018-12-06 01:39:04', 125, '2000.00', 1),
(13, 3, '2018-12-06 01:39:40', 50, '220.00', 1),
(14, 5, '2018-12-06 01:40:25', 200, '400.00', 1),
(15, 5, '2018-12-06 01:46:30', 300, '400.00', 1),
(16, 8, '2018-12-06 01:53:17', 25, '150.00', 1),
(17, 1, '2018-12-09 23:04:02', 100, '115.00', 1),
(18, 2, '2018-12-09 23:12:10', 150, '1550.00', 1),
(19, 8, '2018-12-09 23:25:59', 100, '140.00', 1),
(20, 7, '2018-12-09 23:28:23', 50, '2400.00', 1),
(21, 8, '2018-12-09 23:33:36', 100, '175.00', 1),
(22, 9, '2018-12-28 19:09:14', 50, '2500.00', 2),
(23, 10, '2018-12-28 19:11:14', 100, '240.00', 1),
(24, 11, '2018-12-28 19:14:15', 130, '450.00', 1),
(25, 12, '2018-12-28 19:17:41', 100, '250.00', 1),
(26, 13, '2018-12-28 19:18:43', 150, '650.00', 2),
(27, 14, '2020-08-09 20:23:34', 100, '120.00', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `factura`
--

DROP TABLE IF EXISTS `factura`;
CREATE TABLE IF NOT EXISTS `factura` (
  `nofactura` bigint(11) NOT NULL AUTO_INCREMENT,
  `fecha` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `usuario` int(11) DEFAULT NULL,
  `codcliente` int(11) DEFAULT NULL,
  `totalfactura` decimal(10,2) DEFAULT NULL,
  `estatus` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`nofactura`),
  KEY `usuario` (`usuario`),
  KEY `codcliente` (`codcliente`)
) ENGINE=InnoDB AUTO_INCREMENT=33 DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `factura`
--

INSERT INTO `factura` (`nofactura`, `fecha`, `usuario`, `codcliente`, `totalfactura`, `estatus`) VALUES
(1, '2019-02-18 23:32:42', 1, 7, '3612.96', 1),
(2, '2019-02-20 23:25:32', 1, 7, '983.34', 1),
(3, '2019-02-20 23:27:57', 1, 1, '640.00', 1),
(4, '2019-04-02 23:20:08', 1, 7, '1530.00', 1),
(5, '2019-04-02 23:29:52', 1, 7, '636.67', 1),
(6, '2019-04-02 23:40:56', 1, 7, '2462.96', 1),
(7, '2019-04-03 00:18:00', 1, 7, '14860.00', 1),
(8, '2019-04-03 00:19:31', 1, 7, '334.71', 1),
(9, '2019-04-03 00:22:50', 1, 1, '2682.96', 1),
(10, '2019-04-03 00:24:00', 1, 7, '20220.00', 1),
(11, '2019-04-03 00:24:38', 1, 7, '2556.67', 1),
(12, '2019-04-03 00:25:43', 1, 7, '114.71', 1),
(13, '2019-04-03 00:25:55', 1, 1, '1530.00', 1),
(14, '2019-04-03 00:26:33', 1, 1, '21530.00', 1),
(15, '2019-04-03 00:27:18', 1, 7, '20416.67', 1),
(16, '2019-04-03 00:28:44', 1, 7, '22462.96', 1),
(17, '2019-04-03 00:35:30', 1, 7, '416.67', 1),
(18, '2019-04-03 00:36:12', 1, 1, '114.71', 1),
(19, '2019-04-03 00:36:30', 1, 7, '114.71', 1),
(20, '2019-04-03 00:39:54', 1, 1, '150.00', 2),
(21, '2019-04-03 00:57:54', 1, 1, '1530.00', 2),
(22, '2019-04-03 01:27:31', 1, 7, '20220.00', 1),
(23, '2019-04-03 01:28:42', 1, 1, '3670.00', 2),
(24, '2019-04-11 23:39:18', 1, 1, '1150.00', 2),
(25, '2019-04-14 01:46:51', 1, 1, '20833.34', 2),
(26, '2019-05-08 23:13:40', 1, 16, '1248.05', 1),
(27, '2019-05-09 01:38:37', 1, 7, '2426.67', 1),
(28, '2019-05-25 01:39:06', 1, 7, '1053.34', 1),
(29, '2019-05-25 22:01:07', 3, 13, '806.67', 1),
(30, '2019-06-01 21:51:13', 1, 18, '21010.00', 1),
(31, '2019-06-01 23:02:58', 3, 7, '8796.31', 1),
(32, '2020-08-09 20:21:37', 1, 7, '10940.00', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `producto`
--

DROP TABLE IF EXISTS `producto`;
CREATE TABLE IF NOT EXISTS `producto` (
  `codproducto` int(11) NOT NULL AUTO_INCREMENT,
  `descripcion` varchar(100) DEFAULT NULL,
  `proveedor` int(11) DEFAULT NULL,
  `precio` decimal(10,2) DEFAULT NULL,
  `existencia` int(11) DEFAULT NULL,
  `date_add` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `usuario_id` int(11) NOT NULL,
  `estatus` int(11) NOT NULL DEFAULT '1',
  `foto` text,
  PRIMARY KEY (`codproducto`),
  KEY `proveedor` (`proveedor`),
  KEY `usuario_id` (`usuario_id`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `producto`
--

INSERT INTO `producto` (`codproducto`, `descripcion`, `proveedor`, `precio`, `existencia`, `date_add`, `usuario_id`, `estatus`, `foto`) VALUES
(1, 'Mouse USB', 11, '114.71', 420, '2018-04-05 00:09:34', 1, 1, 'img_44b2b5ce5315656335fbbeddc3d4e156.jpg'),
(2, 'Monitor LCD 15', 11, '1530.00', 242, '2018-04-05 00:12:15', 1, 1, 'img_producto.png'),
(3, 'Teclado USB', 9, '220.00', 341, '2018-04-07 22:48:23', 9, 1, 'img_producto.png'),
(4, 'Cama', 5, '10000.00', 37, '2018-09-08 22:28:50', 1, 1, 'img_21084f55f7b61c8baa2726ad0b4a1dca.jpg'),
(5, 'Plancha', 6, '416.67', 583, '2018-09-08 22:34:38', 1, 1, 'img_25c1e2ae283b99e83b387bf800052939.jpg'),
(6, 'Monitor', 11, '2462.96', 102, '2018-09-08 22:35:27', 1, 1, 'img_producto.png'),
(7, 'Monitor LCD 17', 9, '2140.00', 245, '2018-12-02 00:15:09', 1, 1, 'img_1328286905ecc9eec8e81b94fa1786b9.jpg'),
(8, 'USB 8 GB', 3, '150.00', 394, '2018-12-02 00:39:42', 1, 1, 'img_7696fb932826fb3c08c7af0da95397a8.jpg'),
(9, 'Celular Samsung J3', 7, '2500.00', 48, '2018-12-28 19:09:14', 2, 1, 'img_760856807752e14c15abf9888f539c71.jpg'),
(10, 'Licuadora', 6, '240.00', 93, '2018-12-28 19:11:14', 1, 1, 'img_b644ed7698ed443e66ae9bac4208c96c.jpg'),
(11, 'Adaptador USB - HDMI', 11, '450.00', 126, '2018-12-28 19:14:15', 1, 1, 'img_79ca89de913d49421d21a9d62a128a20.jpg'),
(12, 'Mouse Inalambrico', 11, '250.00', 97, '2018-12-28 19:17:41', 1, 1, 'img_380554c1ccf986ebeeb7f7cbde0c4654.jpg'),
(13, 'Auriculares con Bluetooth', 8, '650.00', 150, '2018-12-28 19:18:43', 2, 1, 'img_243d36d9c5299eaadddf2cbf844c5ef2.jpg'),
(14, 'Ventilador', 12, '120.00', 100, '2020-08-09 20:23:34', 1, 1, 'img_284cd26d7711d1fb0c293280bc7d7fb9.jpg');

--
-- Disparadores `producto`
--
DROP TRIGGER IF EXISTS `entradas_A_I`;
DELIMITER $$
CREATE TRIGGER `entradas_A_I` AFTER INSERT ON `producto` FOR EACH ROW BEGIN
		INSERT INTO entradas(codproducto,cantidad,precio,usuario_id) 
		VALUES(new.codproducto,new.existencia,new.precio,new.usuario_id);    
	END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `proveedor`
--

DROP TABLE IF EXISTS `proveedor`;
CREATE TABLE IF NOT EXISTS `proveedor` (
  `codproveedor` int(11) NOT NULL AUTO_INCREMENT,
  `proveedor` varchar(100) DEFAULT NULL,
  `contacto` varchar(100) DEFAULT NULL,
  `telefono` bigint(20) DEFAULT NULL,
  `direccion` text,
  `date_add` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `usuario_id` int(11) NOT NULL,
  `estatus` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`codproveedor`),
  KEY `usuario_id` (`usuario_id`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `proveedor`
--

INSERT INTO `proveedor` (`codproveedor`, `proveedor`, `contacto`, `telefono`, `direccion`, `date_add`, `usuario_id`, `estatus`) VALUES
(1, 'BIC', 'Claudia Rosales', 789877889, 'Avenida las Americas', '2018-03-20 23:13:43', 1, 0),
(2, 'CASIO', 'Jorge Herrera', 565656565656, 'Calzada Las Flores', '2018-03-20 23:14:41', 2, 0),
(3, 'Omega', 'Julio Estrada', 982877489, 'Avenida Elena Zona 4, Guatemala', '2018-03-24 23:21:10', 1, 1),
(4, 'Dell Compani', 'Roberto Estrada', 2147483647, 'Guatemala, Guatemala', '2018-03-24 23:21:59', 1, 1),
(5, 'Olimpia S.A', 'Elena Franco Morales', 564535676, '5ta. Avenida Zona 4 Ciudad', '2018-03-24 23:22:45', 1, 1),
(6, 'Oster', 'Fernando Guerra', 78987678, 'Calzada La Paz, Guatemala', '2018-03-24 23:24:43', 1, 1),
(7, 'ACELTECSA S.A', 'Ruben PÃ©rez', 789879889, 'Colonia las Victorias', '2018-03-24 23:25:39', 1, 1),
(8, 'Sony', 'Julieta Contreras', 89476787, 'Antigua Guatemala', '2018-03-24 23:26:45', 1, 1),
(9, 'VAIO', 'Felix Arnoldo Rojas', 476378276, 'Avenida las Americas Zona 13', '2018-03-24 23:30:33', 1, 1),
(10, 'SUMAR', 'Oscar Maldonado', 788376787, 'Colonia San Jose, Zona 5 Guatemala', '2018-03-24 23:32:28', 1, 1),
(11, 'HP', 'Angel Cardona', 2147483647, '5ta. calle zona 4 Guatemala', '2018-03-24 23:52:20', 2, 1),
(12, 'Bodegas SA', 'Julio Cesar Costa', 65468465465454, 'Ciudad', '2020-08-09 20:23:00', 1, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `rol`
--

DROP TABLE IF EXISTS `rol`;
CREATE TABLE IF NOT EXISTS `rol` (
  `idrol` int(11) NOT NULL AUTO_INCREMENT,
  `rol` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`idrol`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `rol`
--

INSERT INTO `rol` (`idrol`, `rol`) VALUES
(1, 'Administrador'),
(2, 'Supervisor'),
(3, 'Vendedor');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuario`
--

DROP TABLE IF EXISTS `usuario`;
CREATE TABLE IF NOT EXISTS `usuario` (
  `idusuario` int(11) NOT NULL AUTO_INCREMENT,
  `dpi` bigint(20) DEFAULT NULL,
  `nombre` varchar(50) DEFAULT NULL,
  `correo` varchar(100) DEFAULT NULL,
  `usuario` varchar(15) DEFAULT NULL,
  `clave` varchar(100) DEFAULT NULL,
  `rol` int(11) DEFAULT NULL,
  `estatus` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`idusuario`),
  KEY `rol` (`rol`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=latin1;

--
-- Volcado de datos para la tabla `usuario`
--

INSERT INTO `usuario` (`idusuario`, `dpi`, `nombre`, `correo`, `usuario`, `clave`, `rol`, `estatus`) VALUES
(1, 0, 'Abel O SH', 'info@abelosh.com', 'admin', 'e10adc3949ba59abbe56e057f20f883e', 1, 1),
(2, 0, 'Julio Estrada', 'julio@gmail.com', 'julio', 'c027636003b468821081e281758e35ff', 2, 1),
(3, 0, 'Carlos HernÃ¡ndez', 'carlos@gmail.com', 'carlos', 'dc599a9972fde3045dab59dbd1ae170b', 3, 1),
(5, 0, 'Marta Elena Franco', 'marta@gmail.com', 'marta', 'a763a66f984948ca463b081bf0f0e6d0', 3, 1),
(7, 0, 'Carol Cabrera', 'carol@gmail.com', 'carol', 'a9a0198010a6073db96434f6cc5f22a8', 2, 0),
(8, 0, 'Marvin Solares ', 'marvin@gmail.com', 'marvin', 'dba0079f1cb3a3b56e102dd5e04fa2af', 3, 1),
(9, 0, 'Alan Melgar', 'alan@gmail.com', 'alan', '02558a70324e7c4f269c69825450cec8', 2, 1),
(10, 0, 'Efrain GÃ³mez', 'efrain@gmail.com', 'efrain', '69423f0c254e5c1d2b0f5ee202459d2c', 2, 1),
(11, 0, 'Fran Escobar', 'fran@gmail.com', 'fran', '2c20cb5558626540a1704b1fe524ea9a', 1, 1),
(12, 0, 'Hana Montenegro', 'hana@gmail.com', 'hana', '52fd46504e1b86d80cfa22c0a1168a9d', 3, 1),
(13, 0, 'Fredy Miranda', 'fredy@gmail.com', 'fredy', 'b89845d7eb5f8388e090fcc151d618c8', 2, 1),
(14, 0, 'Roberto Salazar', 'roberto@hotmail.com', 'roberto', 'c1bfc188dba59d2681648aa0e6ca8c8e', 3, 1),
(15, 0, 'William Fernando PÃ©rez', 'william@hotmail.com', 'william', 'fd820a2b4461bddd116c1518bc4b0f77', 3, 1),
(16, 0, 'Francisco Mora', 'frans@gmail.com', 'frans', '64dd0133f9fb666ca6f4692543844f31', 3, 1),
(17, 0, 'Ruben Guevara', 'ruben@hotmail.es', 'ruben', '32252792b9dccf239f5a5bd8e778dbc2', 3, 1),
(18, NULL, 'Angel', 'angelcarrillo@gmail.com', 'angel', '827ccb0eea8a706c4c34a16891f84e7b', 3, 1),
(19, NULL, 'Mario Arana', 'marioarana@gmail.com', 'mario', '202cb962ac59075b964b07152d234b70', 3, 1),
(20, NULL, 'Fernando', 'fer@info.com', 'fernando', 'cebdd715d4ecaafee8f147c2e85e0754', 2, 1);

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `cliente`
--
ALTER TABLE `cliente`
  ADD CONSTRAINT `cliente_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuario` (`idusuario`);

--
-- Filtros para la tabla `detallefactura`
--
ALTER TABLE `detallefactura`
  ADD CONSTRAINT `detallefactura_ibfk_2` FOREIGN KEY (`codproducto`) REFERENCES `producto` (`codproducto`),
  ADD CONSTRAINT `detallefactura_ibfk_3` FOREIGN KEY (`nofactura`) REFERENCES `factura` (`nofactura`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `detalle_temp`
--
ALTER TABLE `detalle_temp`
  ADD CONSTRAINT `detalle_temp_ibfk_2` FOREIGN KEY (`codproducto`) REFERENCES `producto` (`codproducto`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `entradas`
--
ALTER TABLE `entradas`
  ADD CONSTRAINT `entradas_ibfk_1` FOREIGN KEY (`codproducto`) REFERENCES `producto` (`codproducto`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `factura`
--
ALTER TABLE `factura`
  ADD CONSTRAINT `factura_ibfk_1` FOREIGN KEY (`codcliente`) REFERENCES `cliente` (`idcliente`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `factura_ibfk_2` FOREIGN KEY (`usuario`) REFERENCES `usuario` (`idusuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `producto`
--
ALTER TABLE `producto`
  ADD CONSTRAINT `producto_ibfk_1` FOREIGN KEY (`proveedor`) REFERENCES `proveedor` (`codproveedor`),
  ADD CONSTRAINT `producto_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuario` (`idusuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `proveedor`
--
ALTER TABLE `proveedor`
  ADD CONSTRAINT `proveedor_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuario` (`idusuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `usuario`
--
ALTER TABLE `usuario`
  ADD CONSTRAINT `usuario_ibfk_1` FOREIGN KEY (`rol`) REFERENCES `rol` (`idrol`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
