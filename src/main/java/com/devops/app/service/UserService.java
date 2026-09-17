package com.devops.app.service;

import com.devops.app.entity.User;
import com.devops.app.exception.UserNotFoundException;
import com.devops.app.repository.UserRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class UserService {

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public List<User> getAllUsers() {
        return userRepository.findAll();
    }

    public User saveUser(User user) {
        return userRepository.save(user);
    }

    public User getUserById(Long id) {
        return userRepository.findById(id).orElseThrow(() -> new UserNotFoundException("User not foung with id: " + id));
    }

    public User updateUser(Long id, User updateUser) {
        User existingUser = userRepository.findById(id).orElseThrow(() -> new UserNotFoundException("User not foung with id: " + id));
        existingUser.setName(updateUser.getName());
        existingUser.setEmail(updateUser.getEmail());

        return userRepository.save(existingUser);
    }

    public void deleteUser(Long id) {
        User user = userRepository.findById(id).orElseThrow(() -> new UserNotFoundException("User not found with id: " + id));
        userRepository.delete(user);
    }

}
