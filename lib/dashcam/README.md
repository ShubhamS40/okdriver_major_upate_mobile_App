# OkDriver Dashcam Feature

## Overview
The dashcam feature allows users to record video while driving, with options for camera selection, audio recording, and storage preferences. The implementation supports background recording, multiple camera views, and video management.

## Features
- Camera selection (front, back, or dual cameras)
- Video recording with or without audio
- Configurable recording duration (15 min, 30 min, 1 hour)
- Storage options (local device or cloud storage)
- Background recording capability
- Video playback with seek controls
- Video management (view, delete saved recordings)
- Timestamp display on recordings

## Implementation Structure

### Main Components

1. **DashcamScreen** (`dashcam_screen.dart`)
   - Main screen that integrates all dashcam components
   - Manages recording state and user interactions
   - Handles background recording functionality

2. **CameraSelectionScreen** (`components/camera_selection.dart`)
   - Allows users to select camera type (front, back, or dual)
   - Handles camera permissions

3. **VideoPreviewScreen** (`components/video_preview.dart`)
   - Displays live camera preview (25% of screen)
   - Shows recording status indicators
   - Provides video playback interface for saved videos

4. **RecordingControlsScreen** (`components/recording_controls.dart`)
   - Provides controls for recording (start, pause, stop, delete)
   - Allows configuration of recording options (audio, duration, storage)
   - Navigates to subscription plan screen when cloud storage is selected

5. **SavedVideosScreen** (`components/saved_videos_screen.dart`)
   - Lists all saved recordings with metadata
   - Provides playback and deletion options

### Services and Models

1. **CameraService** (`services/camera_service.dart`)
   - Handles camera initialization and recording functionality
   - Manages video files and storage
   - Provides background recording capability

2. **VideoFile** (`models/video_file.dart`)
   - Model class for saved video files
   - Contains metadata (timestamp, duration, size, etc.)
   - Provides utility methods for file operations

## Usage Flow

1. User navigates to the Dashcam tab in the bottom navigation bar
2. User selects camera type (front, back, or dual)
3. User configures recording options:
   - With/without audio
   - Storage location (local or cloud)
   - If cloud is selected, user is directed to subscription plan screen
   - If local is selected, user can select recording duration
4. User starts recording with the record button
5. During recording, user can:
   - Pause/resume recording
   - Stop recording to save the video
   - Delete the current recording
6. Saved videos can be accessed and managed from the saved videos screen

## Technical Notes

- The implementation uses the `video_player` package for video playback
- Camera permissions are handled using the `permission_handler` package
- Videos are saved with timestamps in the filename
- The feature supports background recording when the app is minimized
- Cloud storage integration requires a subscription plan

## Future Enhancements

- Add video quality settings
- Implement video compression options
- Add video editing capabilities
- Implement cloud synchronization for saved videos
- Add GPS data overlay on recordings
- Implement collision detection and automatic recording