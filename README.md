# fashion_tech

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:


For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# FashionTech

FashionTech is a comprehensive inventory and job order management system designed for fashion and tailoring businesses. It streamlines the management of fabrics, products, job orders, and user roles, providing a modern, user-friendly interface built with Flutter and Firebase.

## Project Overview

FashionTech enables users to:
- Manage fabrics, products, and job orders efficiently
- Assign roles (admin, user) with different access levels
- Track inventory and product variants
- View statistics and logs for business insights
- Authenticate users via email/password (with plans for Google/Apple Auth)

The system is designed for scalability and ease of use, with a focus on reliability and maintainability.

## Getting Started

### Prerequisites
- [Flutter](https://flutter.dev/docs/get-started/install) (latest stable version recommended)
- [Dart](https://dart.dev/get-dart)
- [Firebase Project](https://console.firebase.google.com/) (with Firestore, Auth, and Storage enabled)

### Setup Instructions
1. **Clone the repository:**
   ```sh
   git clone <repo-url>
   cd fashion_tech
   ```
2. **Install dependencies:**
   ```sh
   flutter pub get
   ```
3. **Configure Firebase:**
   - Replace the contents of `lib/backend/firebase_options.dart` with your Firebase configuration (see [FlutterFire docs](https://firebase.flutter.dev/docs/cli/)).
   - Ensure your Firebase project has Email/Password authentication enabled.
4. **Run the app:**
   ```sh
   flutter run
   ```

## Project Structure
- `lib/`
  - `main.dart` — App entry point and initialization
  - `backend/` — Firebase and backend configuration
  - `frontend/` — UI components and pages
  - `services/` — Business logic and data services (user, color, category, etc.)
  - `utils/` — Utility classes (e.g., color utilities)
- `test/` — Unit and widget tests
- `pubspec.yaml` — Dependencies and assets

## Features
- **User Authentication:** Email/password login, role-based access (admin/user)
- **Inventory Management:** Fabrics, products, and variants
- **Job Order Management:** Create, edit, and track job orders
- **Statistics & Logs:** View business stats and activity logs
- **Admin Panel:** Manage users, categories, and system settings

## Known Bugs
- Some dropdowns are not user-specific data
- Transactions UI to be improved

## To Implement / Future Work
- Google Authentication
- Apple Authentication
- Forgot Password functionality
- Account Verification

## Documentation
- All major files and services are well-documented with comments for easier onboarding and maintenance.
- For specific implementation details, see the respective markdown files in the project root (e.g., `FABRIC_UI_IMPROVEMENTS_COMPLETE.md`, `JOB_ORDER_ANIMATION_FINAL_SMOOTH_FIX.md`).

## Credits
**FashionTech** was initially developed by:
- Prince Czedrick Nepomuceno
- Justin Andrei Ibanez

For questions or further development, please refer to the code comments and markdown documentation files.

---

*Thank you for continuing the development of FashionTech!*
