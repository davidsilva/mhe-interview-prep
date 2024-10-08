import { ComponentFixture, TestBed } from '@angular/core/testing';

import { UsersHomeComponent } from './users-home.component';

describe('UsersHomeComponent', () => {
  let component: UsersHomeComponent;
  let fixture: ComponentFixture<UsersHomeComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [UsersHomeComponent]
    })
    .compileComponents();

    fixture = TestBed.createComponent(UsersHomeComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
