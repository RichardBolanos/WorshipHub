---
inclusion: auto
description: Overview of WorshipHub platform purpose, features, architecture, and user roles
---

# WorshipHub Product Overview

WorshipHub is a comprehensive worship team management platform designed for churches to streamline their worship ministry operations.

## Core Purpose

Enable churches to manage worship teams, organize song catalogs with chord transposition, plan services with intelligent setlist generation, facilitate real-time team communication, and track member availability.

## Key Features

- Organization & team management with role-based access control
- Advanced song catalog with ChordPro format, transposition, and global song repository
- Smart scheduling with automated setlist generation and duration calculation
- Real-time communication via WebSocket chat and notifications
- Member availability tracking and service confirmations
- Multi-church support with invitation system

## Architecture

The platform consists of two main components:

- **Backend API**: Spring Boot REST API with WebSocket support, implementing Clean Architecture and Domain-Driven Design
- **Frontend UI**: Flutter mobile application with offline-first capabilities and premium UX

## User Roles

- **SUPER_ADMIN**: Platform-wide administration and global catalog management
- **CHURCH_ADMIN**: Church registration, user invitations, and organization management
- **WORSHIP_LEADER**: Team creation, setlist planning, service scheduling
- **TEAM_MEMBER**: Song contributions, availability management, service participation

## Current Status

Production-ready with 100% functional requirements implemented, comprehensive testing (71% coverage), and enterprise-grade security with JWT authentication.
