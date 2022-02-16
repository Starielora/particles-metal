#pragma once

#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

// TODO move to MDLCamera?
class Camera final
{
	float _speedMultiplier = 2.5f;
	float _yaw = -90.0f;	// yaw is initialized to -90.0 degrees since a yaw of 0.0 results in a direction vector pointing to the right so we initially rotate a bit to the left.
	float _pitch = 0.0f;
	float _lastX = 800.0f / 2.0;
	float _lastY = 600.0 / 2.0;
	float _fov = 45.0f;

	glm::vec3 _cameraPos = glm::vec3(0.0f, 0.0f, 3.0f);
	glm::vec3 _cameraFront = glm::vec3(0.0f, 0.0f, -1.0f);
	glm::vec3 _cameraUp = glm::vec3(0.0f, 1.0f, 0.0f);

public:

	auto& speedMultiplier() { return _speedMultiplier; }
	auto& position() { return _cameraPos; }
	auto& fov() { return _fov; }

	auto projection(float width, float height) { return glm::perspective(glm::radians(_fov), width / height, 0.1f, 100.f); }
	auto view() { return glm::lookAt(_cameraPos, _cameraPos + _cameraFront, _cameraUp); }

	void moveForward(float t)
	{
		const auto cameraSpeed = _speedMultiplier * t;
		_cameraPos += cameraSpeed * _cameraFront;
	}

	void moveBack(float t)
	{
		const auto cameraSpeed = _speedMultiplier * t;
		_cameraPos -= cameraSpeed * _cameraFront;
	}

	void strafeLeft(float t)
	{
		const auto cameraSpeed = _speedMultiplier * t;
		_cameraPos -= glm::normalize(glm::cross(_cameraFront, _cameraUp)) * cameraSpeed;
	}

	void strafeRight(float t)
	{
		const auto cameraSpeed = _speedMultiplier * t;
		_cameraPos += glm::normalize(glm::cross(_cameraFront, _cameraUp)) * cameraSpeed;
	}

	void fov(float offset)
	{
		_fov += offset;
		if (_fov < 1.0f)
			_fov = 1.0f;
		if (_fov > 45.0f)
			_fov = 45.0f;
	}
};
