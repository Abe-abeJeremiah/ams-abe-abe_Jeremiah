DROP DATABASE FirstLabExam;
CREATE DATABASE FirstLabExam;
USE FirstLabExam;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE roles (

	id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
	role_name VARCHAR(50) NOT NULL UNIQUE,
	DESCRIPTION TEXT,
	is_sustem_role BOOLEAN DEFAULT FALSE,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP

);

CREATE TABLE users (

	ID INT PRIMARY KEY AUTO_INCREMENT UNIQUE NOT NULL,
	First_name VARCHAR(50),
	Last_name VARCHAR(50),
	Email VARCHAR(50),
	password VARCHAR(50);
	role_ID UUID NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
	is_active BOOLEAN DEFAULT TRUE,
	last_login TIMESTAMP,
	Created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	
	-- Constraints
	CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
	CONSTRAINT full_name_length CHECK (char_length(First_name, Last_name))

);

CREATE TABLE sessions (
	
	ID UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
	user_id UUID NOT NULL REFERENCES user(id) ON DELETE CASCADE,
	refresh_token VARCHAR(500) NOT NULL,
	user_agent TEXT,
	ip_address INET,
	expires_at TIMESTAMP NPT NULL,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	is_active BOOLEAN DEFAULT TRUE
	
);

CREATE TABLE auth_audit_log (

	ID UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
	user_id UUID REFERENCES users(id) ON DELETE SET NULL,
	event_type VARCHAR(50) NOT NULL,
	event_details JSONB,
	ip_address INET,
	user_agent TEXT,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role_id ON users(role_id);
CREATE INDEX idx_users_active ON users(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_refresh_token ON sessions(refresh_token);
CREATE INDEX idx_sessions_expires_at ON sessions(expires_at);
CREATE INDEX idx_audit_log_user_id ON auth_audit_log(user_id);
CREATE INDEX idx_audit_log_created_at ON auth_audit_log(created_at);
CREATE INDEX idx_audit_log_event_type ON auth_audit_log(event_type);

-- =====================================================
-- FUNCTIONS AND TRIGGERS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger to tables
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_roles_updated_at
    BEFORE UPDATE ON roles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- INSERT DEFAULT ROLES
-- =====================================================
INSERT INTO roles (role_name, description, is_system_role) VALUES
('Admin', 'System administrator with full access to all features', TRUE),
('Registrar', 'Academic registrar for enrollment and course management', TRUE),
('Instructor', 'Faculty member for teaching and grading', TRUE),
('Student', 'Enrolled student for viewing courses and grades', TRUE);

-- =====================================================
-- CREATE DEFAULT ADMIN USER
-- Password: admin123 (will be hashed in application)
-- =====================================================
INSERT INTO users (full_name, email, password_hash, role_id)
SELECT 'System Administrator', 'admin@ams.edu', 
       '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4aYJGYxMnC6C5.Oy', 
       id
FROM roles WHERE role_name = 'Admin';

-- =====================================================
-- SAMPLE USERS FOR TESTING
-- =====================================================
-- Registrar
INSERT INTO users (full_name, email, password_hash, role_id)
SELECT 'John Registrar', 'registrar@ams.edu',
       '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4aYJGYxMnC6C5.Oy',
       id FROM roles WHERE role_name = 'Registrar';

-- Instructor
INSERT INTO users (full_name, email, password_hash, role_id)
SELECT 'Dr. Jane Instructor', 'instructor@ams.edu',
       '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4aYJGYxMnC6C5.Oy',
       id FROM roles WHERE role_name = 'Instructor';

-- Student
INSERT INTO users (full_name, email, password_hash, role_id)
SELECT 'Bob Student', 'student@ams.edu',
       '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4aYJGYxMnC6C5.Oy',
       id FROM roles WHERE role_name = 'Student';

-- =====================================================
-- VIEWS FOR COMMON QUERIES
-- =====================================================

-- View: User with role details
CREATE VIEW v_users_with_roles AS
SELECT 
    u.id,
    u.full_name,
    u.email,
    u.is_active,
    u.last_login,
    u.created_at,
    r.id as role_id,
    r.role_name,
    r.description as role_description
FROM users u
INNER JOIN roles r ON u.role_id = r.id;

-- View: Active sessions with user details
CREATE VIEW v_active_sessions AS
SELECT 
    s.id as session_id,
    s.user_id,
    u.full_name,
    u.email,
    r.role_name,
    s.user_agent,
    s.ip_address,
    s.expires_at,
    s.created_at
FROM sessions s
INNER JOIN users u ON s.user_id = u.id
INNER JOIN roles r ON u.role_id = r.id
WHERE s.is_active = TRUE AND s.expires_at > CURRENT_TIMESTAMP;