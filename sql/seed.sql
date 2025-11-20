INSERT INTO Users (userID, name, email, password, dateCreated, type) VALUES
-- (1, "Alice",  "alice@example.com",  "hashedpass1",  "2025-01-10 14:23:00"),
(2, "Bob",    "bob@example.com",    "hashedpass2",  "2025-02-02 09:00:00", "Customer"),
(3, "Carol",  "carol@example.com",  "hashedpass3",  "2025-03-12 18:45:00", "Staff"),
(4, "Dave",   "dave@example.com",   "hashedpass4",  "2025-03-15 08:15:00", "Staff"),
(5, "Eve",    "eve@example.com",    "hashedpass5",  "2025-04-01 11:30:00", "Customer"),
(6, "Frank",  "frank@example.com",  "hashedpass6",  "2024-10-30 14:00:00", "Staff"),
(7, "Grace",  "grace@example.com",  "hashedpass7",  "2025-01-11 13:13:13", "Staff"),
(8, "Harold", "harold@example.com", "hashedpass8",  "2025-02-22 02:22:22", "Staff"),
-- (9, "Iman",   "iman@example.com",   "hashedpass9",  "2025-03-30 03:33:33"),
(10, "James", "james@example.com",  "hashedpass10", "2025-10-11 13:00:00", "Customer");

-- demonstration of default values...
INSERT INTO Users (userID, name, email, password, dateCreated) VALUES
(1, "Alice",  "alice@example.com",  "hashedpass1",  "2025-01-10 14:23:00"),
(9, "Iman",   "iman@example.com",   "hashedpass9",  "2025-03-30 03:33:33");

INSERT INTO Customers (userID, totalMiles, points) VALUES
(1,  15200, 300),
(2,  8700,  180),
(5,  22000, 500),
(9,  17000, 1000),
(10, 3000,  200);

INSERT INTO Employees (userID, salary, startDate, position) VALUES
(3, 92000.00,  "2022-05-01 09:00:00", "Pilot"),
(4, 58000.00,  "2020-11-15 09:00:00", "Flight Attendant"),
(6, 120000.00, "2020-01-01 12:00:00", "CEO"),
(7, 80000.00,  "2021-07-04 14:00:00", "Flight Attendant"),
(8, 60000.00,  "2024-10-30 03:30:15", "Janitor");

INSERT INTO EmployeePositions (id, position) VALUES
(1, "Pilot");
(2, "Flight Attendant")
(3, "Janitor")
(4, "CEO");

INSERT INTO Flights (flightID, status, arrival, departure, airline, model) VALUES
(101, "On Time",   "2025-11-02 20:30:00", "2025-11-02 17:15:00", "SkyJet",    "Boeing 737"),
(102, "Delayed",   "2025-11-03 12:10:00", "2025-11-03 09:45:00", "AeroWings", "Airbus A320"),
(103, "Cancelled", "2025-11-04 19:00:00", "2025-11-04 15:30:00", "SkyJet",    "Boeing 777"),
(104, "On Time",   "2025-11-05 22:00:00", "2025-11-05 18:45:00", "AirNova",   "Boeing 787"),
(105, "On Time",   "2025-11-06 10:15:00", "2025-11-06 06:50:00", "CloudAir",  "Airbus A350");

INSERT INTO Rewards (rewardID, requiredPoints, rewardTier) VALUES
(1, 5000,  1),
(2, 15000, 2),
(3, 30000, 3),
(4, 50000, 4),
(5, 75000, 5);

INSERT INTO TicketPrices (ticketID, firstClassPrice, businessClassPrice, economyPrice) VALUES
(101, 950.00,  650.00, 250.00),
(102, 850.00,  550.00, 220.00),
(103, 1000.00, 700.00, 280.00),
(104, 1100.00, 750.00, 300.00),
(105, 970.00,  640.00, 240.00);

INSERT INTO UserFlights (userID, flightID, ticketID) VALUES
(1, 101, 101),
(2, 101, 102),
(3, 103, 103),
(4, 105, 104),
(5, 105, 105);

INSERT INTO CustomerRewards (userID, rewardID, rewardTier) VALUES
(1,  1, 2),
(2,  2, 1),
(5,  3, 3),
(9,  5, 10),
(10, 4, 1);
