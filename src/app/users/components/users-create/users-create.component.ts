import { Component, inject } from '@angular/core';
import { UsersService } from '../../services/users.service';
import { UsersFormComponent } from '../users-form/users-form.component';
import { User } from '../../models/user.model';

@Component({
  selector: 'app-users-create',
  standalone: true,
  imports: [UsersFormComponent],
  templateUrl: './users-create.component.html',
  styleUrl: './users-create.component.scss',
})
export class UsersCreateComponent {
  usersService = inject(UsersService);

  handleFormSubmit(formData: Omit<User, 'id'>): void {
    console.log(formData);
    this.usersService.createUser(formData).subscribe({
      next: (user) => console.log('User created:', user),
      error: (error) => console.error('Error creating user:', error),
      complete: () => console.log('User creation complete'),
    });
  }
}
